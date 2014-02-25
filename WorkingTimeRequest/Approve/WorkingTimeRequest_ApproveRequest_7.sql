USE HRM_SMS
GO
/****** Object:  StoredProcedure [dbo].[WorkingTimeRequest_ApproveRequest_7]    Script Date: 2013-11-07 9:55:07 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[WorkingTimeRequest_ApproveRequest_7]
	@RequestID bigint,	
	@EmpId int,
	@ApprovedBy int,
	@ApprovedDate datetime,
	@RoleID INT,
	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(200) = '' OUTPUT
AS
/*
Created: Tom.Vo@2013-11-13
Task: approve keep in view request form (type 7)
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
*/
SET NOCOUNT ON;
-- get all request detail 
DECLARE @FromDate datetime,@ToDate datetime,@IsHalfDay BIT
	
SELECT TOP 1 @FromDate = FromDate,
	@ToDate = ToDate,
	@IsHalfDay = IsHalfDay
FROM dbo.KeepInViewRequest WITH(NOLOCK)
WHERE RequestID = @RequestID

 

SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION AAA;
	
	--EXEC [dbo].[EmployeeCalendar_Insert]
	--	@empid =@empid,
	--	@fromdate =@WorkDate, 
	--	@todate =@WorkDate,
	--	@ErrCode = @ErrCode  OUTPUT,
	--	@ErrMsg = @ErrMsg  OUTPUT

	--IF 	@ErrCode <> 0
	--BEGIN
	--	ROLLBACK TRANSACTION AAA;
	--	RETURN
	--END

     IF @RoleID = 2  --Verifier
		BEGIN
			UPDATE dbo.WorkingTimeRequest WITH(ROWLOCK,UPDLOCK)
			SET  [CurrentStatus] = 2,
				VerifierId= @ApprovedBy,
				VerifiedDate= @ApprovedDate,
				VerifiedStatus=2
				--ModifiedDate = @ApprovedDate,
				--ModifiedBy = @ApprovedBy
			WHERE RequestID = @RequestID
		END
	ELSE IF @RoleID = 3 --Approver
		BEGIN
			UPDATE EmployeeSummary WITH (ROWLOCK,UPDLOCK)
			SET KeepInViewBalance = ISNULL(KeepInViewBalance,0)+CASE WHEN @IsHalfDay =1 THEN 0.5 ELSE 1 END
			WHERE EmpId = @EmpId

			-- update the working calendar to record the check-in time
			UPDATE cl WITH (ROWLOCK,UPDLOCK)
			SET 
				cl.IsKeepInView = 1,
				--cl.ShiftId = csd.ShiftId,
				--cl.ChangeShiftId = cl.ShiftId,
				cl.LeaveDay = CASE WHEN csd.IsHalfDay = 1 THEN 0.5 ELSE 0 END,
				cl.ModifiedDate = @ApprovedDate,
				cl.ModifiedBy = @ApprovedBy				
			FROM dbo.EmployeeCalendar cl
				INNER JOIN dbo.KeepInViewRequest csd WITH(NOLOCK)
					ON (cl.WorkDate BETWEEN csd.FROMDate AND csd.ToDate)
						AND cl.EmpId = csd.EmpId
			WHERE cl.EmpID = @EmpId AND csd.RequestID = @RequestID
	
			-- process the calendar into attendance
			EXEC EmployeeAttendance_ProcessingAndInsert @EmpId,  @FromDate, @ToDate, 1

			-- update status of request
			UPDATE dbo.WorkingTimeRequest WITH(ROWLOCK,UPDLOCK)
			SET [CurrentStatus] = 4, -- approved
				ApproverId= @ApprovedBy,
				ApprovedDate= @ApprovedDate,
				ApprovedStatus=2
				--ModifiedDate = @ApprovedDate,
				--ModifiedBy = @ApprovedBy
			WHERE RequestID = @RequestID
		END
	ELSE IF @RoleID = 6 --HR
		BEGIN
			UPDATE dbo.WorkingTimeRequest WITH(ROWLOCK,UPDLOCK)
			SET [CurrentStatus] = 6,
				HRId= @ApprovedBy,
				HRDate= @ApprovedDate,
				HRStatus=2
				--ModifiedDate = @ApprovedDate,
				--ModifiedBy = @ApprovedBy
			WHERE RequestID = @RequestID
		END
	COMMIT TRANSACTION AAA;
	SELECT @ErrCode=0;
END TRY
BEGIN CATCH
	SELECT @ErrCode=100,@ErrMsg = 'Aprrove process failed'
	ROLLBACK TRANSACTION AAA;
END CATCH;