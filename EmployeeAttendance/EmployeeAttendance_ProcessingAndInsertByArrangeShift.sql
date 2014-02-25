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

DECLARE @EmpID INT

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

	DELETE dbo.OTDailyRequest 
		WHERE OTDailyRequest.OvertimeDate = @ondate
			AND OTDailyRequest.EmpId = @EmpID
			AND OTDailyRequest.Status in (1,3,5,7)

	FETCH NEXT FROM CursorEmp INTO @EmpID

END

Close CursorEmp 
DEALLOCATE CursorEmp