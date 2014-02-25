--USE HRM_SMS
GO
/****** Object:  StoredProcedure [dbo].[WorkingTimeRequest_DisapproveRequest_6]    Script Date: 2013-11-07 4:38:31 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[WorkingTimeRequest_RejectRequest_6]
	@RequestID bigint,	
	@EmpId int,	
	@ModifiedDate datetime,
	@ModifiedBy int,
	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(200) = '' OUTPUT
AS
/*
Created: Tom.Vo@2013-11-07
Task: disapprove leave request form (type 6)
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @LeaveTypeID int, @TotalDays numeric(5,1),@FromDate datetime, @ToDate datetime,@bFlagLeaveSpecial bit,@LeaveTransId bigint
DECLARE @_FromDate DATETIME, @_LeaveTypeID SMALLINT,@CursorLRD Cursor
DECLARE @LeaveTypeID_OLD int, @LeaveTypeID2_OLD int, @LeaveDay_OLD int
DECLARE @KIVLeave NUMERIC(18,2)

SET @LeaveTransId = 0
-- get request detail
select @FromDate = lr.FromDate, 
	@ToDate = lr.ToDate, 
	@LeaveTypeID = lr.LeaveType, 
	@TotalDays = lr.TotalDays,
	@bFlagLeaveSpecial = CASE WHEN lrd.RequestId IS NULL THEN 0 ELSE 1 END
FROM dbo.LeaveRequest lr WITH(NOLOCK)
	LEFT JOIN dbo.LeaveRequestDetail lrd WITH(NOLOCK)
		ON lr.RequestId = lrd.RequestId
WHERE lr.RequestID = @RequestID

BEGIN TRY
    BEGIN TRANSACTION _RejectRequest_6;
	--IF(@TotalDays <> 0)
	BEGIN
		IF @bFlagLeaveSpecial = 0
			BEGIN
				SELECT @LeaveTypeID_OLD=LeaveTypeID , @LeaveTypeID2_OLD = LeaveTypeID2, @LeaveDay_OLD =LeaveDay
				FROM dbo.EmployeeCalendar WITH(NOLOCK) 
				WHERE EmpID = @EmpId and WorkDate between convert(varchar(10),@FromDate,111) and convert(varchar(10),@ToDate,111)

				-- update the working calendar to clear the check-in time
				IF @LeaveTypeID2_OLD IS NULL 
					BEGIN
							UPDATE dbo.EmployeeCalendar  WITH(ROWLOCK,UPDLOCK)
							SET IsLeaveDay = 0,
								LeaveTypeID = NULL,
								LeaveDay = 0,
								ModifiedDate = @ModifiedDate,
								ModifiedBy = @ModifiedBy 
							WHERE EmpID = @EmpId and	
								WorkDate between convert(varchar(10),@FromDate,111) and convert(varchar(10),@ToDate,111) -- cut off time before compare
					END
				ELSE IF @LeaveTypeID2_OLD IS NOT NULL 
					BEGIN
							UPDATE dbo.EmployeeCalendar  WITH(ROWLOCK,UPDLOCK)
							SET IsLeaveDay = 1,
								LeaveTypeID = CASE WHEN @LeaveTypeID_OLD= @LeaveTypeID THEN  @LeaveTypeID2_OLD ELSE @LeaveTypeID_OLD END,
								LeaveTypeId2 = NULL,
								LeaveDay = 0.5,
								ModifiedDate = @ModifiedDate,
								ModifiedBy = @ModifiedBy 
							WHERE EmpID = @EmpId and	
								WorkDate between convert(varchar(10),@FromDate,111) and convert(varchar(10),@ToDate,111) -- cut off time before compare
					END
					
				-- get id from the leave trans
				SELECT @LeaveTransId = LeaveTransId
				FROM dbo.LeaveTrans  WITH(NOLOCK)
				WHERE RequestId = @RequestId and
					EmpID = @EmpId and	ISNULL(Deleted,0)=0
	
				-- delete the leave transaction
				IF (ISNULL(@LeaveTransId,0) <> 0)	
					EXEC AnnualLeave_DeleteTransaction @LeaveTransId,@ModifiedDate,@ModifiedBy,@ErrCode  =@ErrCode OUTPUT ,@ErrMsg = @ErrMsg OUTPUT
					
				-- process the calendar into attendance
				EXEC EmployeeAttendance_ProcessingAndInsert @EmpId,  @FromDate, @ToDate, 1
			END
		ELSE
			BEGIN
				UPDATE EC
							SET EC.IsLeaveDay = CASE WHEN EC.LeaveTypeId2 IS NOT NULL THEN 1 ELSE 0 END,
								EC.LeaveTypeID = CASE WHEN EC.LeaveTypeId2 IS  NOT NULL THEN EC.LeaveTypeID2 ELSE NULL END,
								EC.LeaveTypeID2 = NULL,
								EC.LeaveDay = 	case when (EC.LeaveDay = 1) then 
													case when lrd.IsHalfDay = 1 then 0.5 else 0 end 
												else 0 end,
								EC.ModifiedDate = @ModifiedDate,
								EC.ModifiedBy = @ModifiedBy 
							FROM dbo.EmployeeCalendar EC WITH(ROWLOCK,UPDLOCK)
								INNER JOIN dbo.LeaveRequestDetail lrd WITH(NOLOCK)
									ON EC.WorkDate = lrd.OnDate
							WHERE EC.EmpID = @EmpId 
								and	lrd.RequestId = @RequestID
								and EC.IsOffDay = 0 and EC.IsHoliday = 0 and EC.IsKeepInView = 0
								and EC.WorkDate between convert(varchar(10),@FromDate,111) and convert(varchar(10),@ToDate,111) -- cut off time before compare

				UPDATE EC
				SET EC.IsLeaveDay = CASE WHEN EC.LeaveTypeId2 IS NOT NULL AND EC.LeaveTypeId2 > 0 THEN 1 ELSE 0 END,
								EC.LeaveTypeID = CASE WHEN EC.LeaveTypeId2 IS  NOT NULL THEN EC.LeaveTypeID2 ELSE NULL END,
								EC.LeaveTypeID2 = NULL,
								EC.LeaveDay = 	case when (EC.LeaveDay = 1) then 
													case when lrd.IsHalfDay = 1 then 0.5 else 0 end 
												else 0 end,
								EC.ModifiedDate = @ModifiedDate,
								EC.ModifiedBy = @ModifiedBy 
				FROM dbo.EmployeeCalendar EC WITH(ROWLOCK,UPDLOCK)
					INNER JOIN dbo.LeaveRequestDetail lrd WITH(NOLOCK)
						ON EC.WorkDate = lrd.OnDate AND EC.LeaveTypeId <> lrd.LeaveType
				WHERE EC.EmpID = @EmpId 
					and	lrd.RequestId = @RequestID
					and lrd.IsHalfDay = 1
					and EC.IsOffDay = 0 and EC.IsHoliday = 0 and EC.IsKeepInView = 0
					and EC.WorkDate between convert(varchar(10),@FromDate,111) and convert(varchar(10),@ToDate,111) -- cut off time before compare

				UPDATE EC
				SET EC.IsOffDay=0,
					EC.IsPublic =1
				FROM dbo.EmployeeCalendar EC WITH(ROWLOCK,UPDLOCK)
					INNER JOIN dbo.LeaveRequestDetail lrd WITH(NOLOCK)
						ON EC.WorkDate = lrd.OnDate AND EC.EmpId = lrd.EmpId
					INNER JOIN dbo.WorkingTimeRequest wkr WITH(NOLOCK)
						ON EC.ModifiedBy = wkr.ApproverId AND lrd.RequestId = wkr.RequestId 
				WHERE EC.EmpID = @EmpId 
					AND	lrd.WorkType = 1
					AND	lrd.RequestId = @RequestID
					AND EC.ShiftId IS NULL

				SET @CursorLRD = CURSOR FOR
				SELECT OnDate 
				FROM dbo.LeaveRequestDetail WITH(NOLOCK)
				WHERE RequestId = @RequestID AND EmpId = @EmpId 
					
				OPEN @CursorLRD
				FETCH NEXT FROM @CursorLRD INTO @_FromDate 
				WHILE @@FETCH_STATUS = 0
				BEGIN
					-- process the calendar into attendance
					select @LeaveTransId = LeaveTransId
					from dbo.LeaveTrans  WITH(NOLOCK)
					where RequestId = @RequestId and
						EmpID = @EmpId and	
						FromDate = @_FromDate and ToDate=@_FromDate
						AND ISNULL(Deleted,0)=0
	
						-- delete the leave transaction
						IF (ISNULL(@LeaveTransId,0) <> 0)	
							EXEC AnnualLeave_DeleteTransaction @LeaveTransId,@ModifiedDate,@ModifiedBy	

					FETCH NEXT FROM @CursorLRD INTO @_FromDate 
				END
				CLOSE @CursorLRD
				DEALLOCATE @CursorLRD

			END
				
	END	
	
	EXEC [dbo].WorkingTimeRequest_Delete_TmpLeaveBalance
		@Requestid = @Requestid,
		@EmpID = @EmpID,
		@Status=2	

	SELECT @KIVLeave = SUM(TotalDays) FROM dbo.tmpKIVLeaveBalance WITH(NOLOCK) WHERE EmpID = @EmpID AND Requestid = @Requestid
	IF ISNULL(@KIVLeave,0) > 0
	BEGIN
		UPDATE EmployeeSummary WITH (ROWLOCK,UPDLOCK)
		SET KeepInViewBalance = ISNULL(KeepInViewBalance,0)+@KIVLeave
		WHERE EmpId = @EmpId
	END

	EXEC [dbo].WorkingTimeRequest_Delete_TmpKIVLeaveBalance
		@Requestid = @Requestid,
		@EmpID = @EmpID,
		@Status=2

	COMMIT TRANSACTION _RejectRequest_6;
	SET @ErrCode = 0

END TRY
BEGIN CATCH
	--SELECT @ErrCode , ERROR_MESSAGE ()
	SELECT @ErrCode=100,@ErrMsg = 'Reject  process failed'
	ROLLBACK TRANSACTION  _RejectRequest_6;
END CATCH;	