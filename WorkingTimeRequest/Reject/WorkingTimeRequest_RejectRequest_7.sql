USE HRM_SMS
GO
/****** Object:  StoredProcedure [dbo].[WorkingTimeRequest_DisapproveRequest_6]    Script Date: 2013-11-07 4:38:31 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[WorkingTimeRequest_RejectRequest_7]
	@RequestID bigint,	
	@EmpId int,	
	@ModifiedDate datetime,
	@ModifiedBy int,
	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(200) = '' OUTPUT
AS
/*
Created: Tom.Vo@2013-11-07
Task: disapprove Keep In View request form (type 7)
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @FromDate datetime, @ToDate datetime,@IsHalfDay BIT

-- get request detail
select @FromDate = lr.FromDate, 
	@ToDate = lr.ToDate,
	@IsHalfDay = IsHalfDay
FROM dbo.KeepInViewRequest lr WITH(NOLOCK)
WHERE lr.RequestID = @RequestID


BEGIN TRY
    BEGIN TRANSACTION _RejectRequest_7;
		UPDATE EmployeeSummary WITH (ROWLOCK,UPDLOCK)
		SET KeepInViewBalance = ISNULL(KeepInViewBalance,0)-CASE WHEN @IsHalfDay =1 THEN 0.5 ELSE 1 END
		WHERE EmpId = @EmpId

		-- update the working calendar to record the check-in time
		UPDATE cl WITH (ROWLOCK,UPDLOCK)
		SET 
			cl.IsKeepInView = 0,
			--cl.ChangeShiftId = NULL,
			--cl.ShiftId = ChangeShiftId ,
			cl.LeaveDay = 0,
			cl.ModifiedDate = @ModifiedDate,
			cl.ModifiedBy = @ModifiedBy	
		FROM dbo.EmployeeCalendar cl
			INNER JOIN dbo.KeepInViewRequest csd WITH(NOLOCK)
				ON (cl.WorkDate BETWEEN csd.FROMDate AND csd.ToDate)
					AND cl.EmpId = csd.EmpId
		WHERE cl.EmpID = @EmpId AND csd.RequestID = @RequestID
	
		EXEC EmployeeAttendance_ProcessingAndInsert @EmpId,  @FromDate, @ToDate, 1

	COMMIT TRANSACTION _RejectRequest_7;
	SET @ErrCode = 0

END TRY
BEGIN CATCH
	--SELECT @ErrCode , ERROR_MESSAGE ()
	SELECT @ErrCode=100,@ErrMsg = 'Reject  process failed'
	ROLLBACK TRANSACTION  _RejectRequest_7;
END CATCH;	