USE HRM_SMS
GO
/****** Object:  StoredProcedure [dbo].[WorkingTimeRequest_DisapproveRequest_6]    Script Date: 2013-11-07 4:38:31 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[WorkingTimeRequest_RejectRequest_2]
	@RequestID bigint,	
	@EmpId int,	
	@ModifiedDate datetime,
	@ModifiedBy int,
	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(200) = '' OUTPUT
AS
/*
Created: Tom.Vo@2013-11-07
Task: disapprove Check out request form (type 2)
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @WorkDate datetime

SELECT @WorkDate = OnDate
FROM dbo.InoutMissRequest WITH(NOLOCK) 
WHERE RequestID = @RequestID


BEGIN TRY
    BEGIN TRANSACTION _RejectRequest_4;

	UPDATE EC
		SET  RequestedCheckoutTime = NULL,
			EC.ModifiedDate = @ModifiedDate,
			EC.ModifiedBy = @ModifiedBy 
		FROM EmployeeCalendar EC WITH(ROWLOCK,UPDLOCK)
		WHERE WorkDate = @WorkDate AND EC.EmpID = @EmpId

		-- process the calendar into attendance
		EXEC EmployeeAttendance_ProcessingAndInsert @EmpId,  @WorkDate, @WorkDate, 1
	

	COMMIT TRANSACTION _RejectRequest_4;
	SET @ErrCode = 0

END TRY
BEGIN CATCH
	--SELECT @ErrCode , ERROR_MESSAGE ()
	SELECT @ErrCode=100,@ErrMsg = 'Reject  process failed'
	ROLLBACK TRANSACTION  _RejectRequest_4;
END CATCH;	