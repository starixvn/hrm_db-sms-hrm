USE HRM_SMS
GO
/****** Object:  StoredProcedure [dbo].[WorkingTimeRequest_DisapproveRequest_6]    Script Date: 2013-11-07 4:38:31 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[WorkingTimeRequest_RejectRequest_5]
	@RequestID bigint,	
	@EmpId int,	
	@ModifiedDate datetime,
	@ModifiedBy int,
	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(200) = '' OUTPUT
AS
/*
Created: Tom.Vo@2013-11-07
Task: disapprove change shift request form (type 5)
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @FromDate datetime, @ToDate datetime

-- get request detail
select @FromDate = lr.FromDate, 
	@ToDate = lr.ToDate
FROM dbo.ChangeShiftRequest lr WITH(NOLOCK)
WHERE lr.RequestID = @RequestID


BEGIN TRY
    BEGIN TRANSACTION _RejectRequest_6;

	UPDATE EC
		SET  EC.ChangeShiftID = null,
			EC.ShiftId = FromShift,
			EC.ModifiedDate = @ModifiedDate,
			EC.ModifiedBy = @ModifiedBy 
		FROM EmployeeCalendar EC
			INNER JOIN ChangeShiftRequestDetail csd WITH(NOLOCK)
				ON WorkDate = OnDate AND EC.EmpID = csd.EmpId
		WHERE csd.RequestId = @RequestID 

		-- process the calendar into attendance
		EXEC EmployeeAttendance_ProcessingAndInsert @EmpId,  @FromDate, @ToDate, 1
	

	COMMIT TRANSACTION _RejectRequest_6;
	SET @ErrCode = 0

END TRY
BEGIN CATCH
	--SELECT @ErrCode , ERROR_MESSAGE ()
	SELECT @ErrCode=100,@ErrMsg = 'Reject  process failed'
	ROLLBACK TRANSACTION  _RejectRequest_6;
END CATCH;	