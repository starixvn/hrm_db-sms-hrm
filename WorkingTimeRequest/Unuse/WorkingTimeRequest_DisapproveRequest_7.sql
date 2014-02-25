USE HRM_SMS
GO
/****** Object:  StoredProcedure [dbo].[WorkingTimeRequest_DisapproveRequest_7]    Script Date: 2013-11-07 4:38:31 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[WorkingTimeRequest_DisapproveRequest_7]
	@RequestID bigint,	
	@EmpId int,	
	@ModifiedDate datetime,
	@ModifiedBy int,
	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(200) = '' OUTPUT
AS
/*
Created: Tom.Vo@2013-11-07
Task: disapprove leave request form (type 7)
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @WorkDate datetime
	
SELECT TOP 1 @WorkDate = OnDate
FROM dbo.KeepInViewRequest WITH(NOLOCK)
WHERE RequestID = @RequestID

BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE EmployeeSummary WITH (ROWLOCK,UPDLOCK)
	SET KeepInViewBalance = ISNULL(KeepInViewBalance,0)+1
	WHERE EmpId = @EmpId
	-- update the working calendar to record the check-in time
	UPDATE cl
		SET  cl.ChangeShiftID = NULL,
			cl.ShiftId = NULL,
			cl.IsKeepInView=0,
			cl.ModifiedDate = @ModifiedDate,
			cl.ModifiedBy = @ModifiedBy
		FROM dbo.EmployeeCalendar cl
			INNER JOIN dbo.ChangeShiftRequestDetail csd WITH(NOLOCK)
				ON cl.WorkDate = csd.OnDate
					AND cl.EmpId = csd.EmpId
		WHERE cl.EmpID = @EmpId AND csd.RequestID = @RequestID

	-- process the calendar into attendance
	EXEC EmployeeAttendance_ProcessingAndInsert @EmpId,  @WorkDate, @WorkDate, 1
	
	-- update status of request
	UPDATE dbo.WorkingTimeRequest WITH(ROWLOCK,UPDLOCK)
	SET [CurrentStatus] = 1, -- pending
		ApprovedStatus = 1,
		ModifiedDate = @ModifiedDate,	
		ModifiedBy = @ModifiedBy 
	WHERE RequestID = @RequestID

	COMMIT TRANSACTION;
	SELECT @ErrCode=0;
END TRY
BEGIN CATCH
	SELECT @ErrCode=100,@ErrMsg = 'DisAprrove process failed'
	ROLLBACK TRANSACTION;
END CATCH;