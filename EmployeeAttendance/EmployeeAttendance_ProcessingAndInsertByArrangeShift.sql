GO
/****** Object:  StoredProcedure [dbo].[EmployeeAttendance_ProcessingANDINSERT]    Script Date: 2013-11-13 3:01:05 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[EmployeeAttendance_ProcessingAndInsertByArrangeShift]
	@sEmpid VARCHAR(1000), 
	@ondate DATETIME,

	@ErrCode INT = 0 OUTPUT,
	@ErrMsg VARCHAR(200) = '' OUTPUT,
	@Debug BIT=0

		
AS
/*
Created:  Tom.Vo@2014.01.16
Task: Process the working Calendar AND INSERT the attENDance data for EmployeeAttendance
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
	@empid: the employee id to process (null IF process all)
	@fromtime: the date to start process
	@totime: the date to END process
*/
SET NOCOUNT ON;

DECLARE @onlyUPDATE BIT = 1

DECLARE @EmpID INT,@RequestId_OT INT

DECLARE CursorEmp Cursor FOR
Select Val from 
	dbo.fnc_strSplit(@sEmpID,',')

OPEN CursorEmp
FETCH NEXT FROM CursorEmp INTO @EmpID
WHILE @@FETCH_STATUS = 0
BEGIN
	EXEC[dbo].[EmployeeAttendance_ProcessingAndInsert]
		@Empid = @EmpID,
		@FromTime= @OnDate,
		@ToTime = @ondate,
		@onlyUPDATE=@onlyUPDATE

	SELECT TOP 1 @RequestId_OT = RequestId 
	FROM dbo.OTDailyRequest (NOLOCK)
		WHERE OTDailyRequest.OvertimeDate = @ondate
			AND OTDailyRequest.EmpId = @EmpID
			AND OTDailyRequest.Status in (1,3,5,7)
	IF @RequestId_OT IS NOT NULL 
	BEGIN
		DELETE dbo.OTDailyRequest 
			WHERE OTDailyRequest.OvertimeDate = @ondate
				AND OTDailyRequest.EmpId = @EmpID
				AND OTDailyRequest.Status in (1,3,5,7)
	
		IF @@ROWCOUNT > 0
		BEGIN			
			UPDATE OT
			SET 	
					OT.[NormalHours] = ISNULL(rd.[NormalHours],0),
					OT.[OffHours] = ISNULL(rd.[OffHours],0),
					OT.[PublicHours]=ISNULL(rd.[PublicHours],0)
			FROM [OTMonthlyRequest]  OT WITH(ROWLOCK,UPDLOCK)
			INNER JOIN 
				( SELECT SUM(ISNULL([NormalHours],0)) [NormalHours] ,
						SUM(ISNULL([OffHours],0)) [OffHours],
						SUM(ISNULL([PublicHours],0)) [PublicHours],  
						@RequestId_OT RequestId
					FROM OTdailyRequest rd WITH(NOLOCK)
					WHERE rd.RequestId = @RequestId_OT
				)rd
				ON OT.RequestId = rd.RequestId
			WHERE OT.RequestId = @RequestId_OT
		END
	END

	FETCH NEXT FROM CursorEmp INTO @EmpID

END

Close CursorEmp 
DEALLOCATE CursorEmp