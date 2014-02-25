USE HRM_SMS
GO
/****** Object:  StoredProcedure [dbo].[WorkingTimeRequest_ApproveRequest_7]    Script Date: 2013-11-07 9:55:07 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].WorkingTimeRequest_ResetRequest_7
	@RequestID bigint,	
	@EmpId int,
	@ApprovedBy int,
	@ApprovedDate datetime,
	@RoleID INT,
	@CurrentStatus int=NULL,
	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(200) = '' OUTPUT
AS
/*
Created: Tom.Vo@2013-11-13
Task: Reset Status keep in view request form (type 7)
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
*/
SET NOCOUNT ON;

DECLARE @CurrentStatus_old INT

IF @CurrentStatus IS NULL
	SELECT TOP 1 @CurrentStatus = [CurrentStatus]
	FROM dbo.WorkingTimeRequest WITH(NOLOCK)
	WHERE RequestID = @RequestID

IF @RoleID <> 2
	SELECT TOP 1 @CurrentStatus_old = CurrentStatus FROM dbo.WorkingTimeRequestHistory WITH(NOLOCK)
	WHERE RequestID = @RequestID AND CurrentStatus< @CurrentStatus
	ORDER BY InsertedDate DESC

SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION AAA;

     IF @RoleID = 2  --Verifier
		BEGIN
			UPDATE dbo.WorkingTimeRequest WITH(ROWLOCK,UPDLOCK)
			SET  [CurrentStatus] = 1,
				VerifierId= @ApprovedBy,
				VerifiedDate= @ApprovedDate,
				VerifiedStatus=1
			WHERE RequestID = @RequestID
		END
	ELSE IF @RoleID = 3 --Approver
		BEGIN
			IF @CurrentStatus = 4
			BEGIN
				EXEC  [dbo].[WorkingTimeRequest_RejectRequest_7]
					@RequestID =@RequestID,	
					@EmpId =@EmpId ,	
					@ModifiedDate =@ApprovedDate,
					@ModifiedBy =@ApprovedBy,
					@ErrCode = @ErrCode OUTPUT,
					@ErrMsg = @ErrMsg  OUTPUT
			END

			-- update status of request
			UPDATE dbo.WorkingTimeRequest WITH(ROWLOCK,UPDLOCK)
			SET [CurrentStatus] = @CurrentStatus_old, -- approved
				ApproverId= @ApprovedBy,
				ApprovedDate= @ApprovedDate,
				ApprovedStatus=1 
			WHERE RequestID = @RequestID
		END
	ELSE IF @RoleID = 6 --HR
		BEGIN
			UPDATE dbo.WorkingTimeRequest WITH(ROWLOCK,UPDLOCK)
			SET [CurrentStatus] = @CurrentStatus_old,
				HRId= @ApprovedBy,
				HRDate= @ApprovedDate,
				HRStatus=1 
			WHERE RequestID = @RequestID
		END
	COMMIT TRANSACTION AAA;
	SELECT @ErrCode=0;
END TRY
BEGIN CATCH
	SELECT @ErrCode=100,@ErrMsg = 'Reset Status process failed'
	ROLLBACK TRANSACTION AAA;
END CATCH;