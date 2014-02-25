--USE HRM_SMS
GO
/****** Object:  StoredProcedure [dbo].[WorkingTimeRequest_ApproveRequest_6]    Script Date: 2013-11-07 1:59:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].WorkingTimeRequest_ResetRequest_byMember_6
	@RequestID bigint,	
	@EmpId int,
	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(200) = '' OUTPUT
AS
/*
Created: Tom.Vo@2013-11-07
Task: Reset Status  leave request form (type 6)
DB: HRM_SMS
Original: 

Revisions:
Param's Explanation:
*/
SET NOCOUNT ON
DECLARE @CurrentStatus INT
DECLARE @ApprovedBy_old INT,@ApprovedDate_old DATETIME
		,@FROMDate DATETIME, @ToDate DATETIME
		,@ReworkCount INT


--IF @CurrentStatus IS NULL
SELECT TOP 1 @CurrentStatus = wk.[CurrentStatus]
		,@ApprovedBy_old = @EmpId
		,@ApprovedDate_old = Getdate()
		,@FromDate = lr.FromDate
FROM dbo.WorkingTimeRequest wk WITH(NOLOCK)
	LEFT JOIN dbo.LeaveRequest lr WITH(NOLOCK)
		ON wk.RequestId = lr.RequestId
WHERE wk.RequestID = @RequestID AND wk.EmpId = @EmpId

IF (@CurrentStatus > 1)
	BEGIN
		select @ReworkCount = COUNT(wkr.CurrentStatus)
		 FROM [dbo].WorkingTimeRequestHistory wkr  WITH(NOLOCK)
		 INNER JOIN [dbo].[LeaveRequestHistory] lr  WITH(NOLOCK)
			ON wkr.RequestId = lr.RequestId AND wkr.InsertedDate < lr.InsertedDate 
		 WHERE lr.RequestId = @RequestID AND wkr.CurrentStatus >1
		
		IF (@ReworkCount > 1)
			BEGIN
				SET @ErrCode =111
				SET @ErrMsg = 'This request was reedited already. You cannot reedit anymore.'
				RETURN;
			END		

		IF @CurrentStatus <> 1 AND CONVERT(DATETIME,CONVERT(NVARCHAR(25),@FromDate,111)) <= CONVERT(DATETIME,CONVERT(NVARCHAR(25),GETDATE(),111))
			BEGIN
				SET @ErrCode =112
				SET @ErrMsg = 'Process awaiting approval. You could not edit this request.'
				RETURN;
			END					
	END
ELSE
	BEGIN
			SET @ErrCode =113
			SET @ErrMsg = 'Your request is pending. Could not reset this request.'
			RETURN;
	END

SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
	IF @CurrentStatus IN (2,3)
		UPDATE dbo.WorkingTimeRequest WITH(ROWLOCK,UPDLOCK)
		SET [CurrentStatus] = 1,
			VerifiedStatus=1
		WHERE RequestID = @RequestID
	ELSE IF @CurrentStatus IN (4,5)
		UPDATE dbo.WorkingTimeRequest WITH(ROWLOCK,UPDLOCK)
		SET [CurrentStatus] = 1,
			VerifiedStatus=1,
			ApprovedStatus=1
		WHERE RequestID = @RequestID
	ELSE IF @CurrentStatus IN (6,7)
		UPDATE dbo.WorkingTimeRequest WITH(ROWLOCK,UPDLOCK)
		SET [CurrentStatus] = 1,
			VerifiedStatus=1,
			ApprovedStatus=1,
			HRStatus =1
		WHERE RequestID = @RequestID

	IF @CurrentStatus IN (4,6)
	BEGIN
		EXEC  [dbo].[WorkingTimeRequest_RejectRequest_6]
			@RequestID =@RequestID,	
			@EmpId =@EmpId ,	
			@ModifiedDate =@ApprovedDate_old,
			@ModifiedBy =@EmpId,
			@ErrCode = @ErrCode OUTPUT,
			@ErrMsg = @ErrMsg  OUTPUT
	END
	IF @CurrentStatus IN (4,6,7)
	BEGIN
		DELETE dbo.LeaveTrans WHERE Requestid = @Requestid
	END
	IF @CurrentStatus IN (4,5,6,7)
	BEGIN
		UPDATE dbo.[tmpLeaveBalance]	WITH(ROWLOCK,UPDLOCK) SET [Status] = 0  WHERE Requestid = @Requestid
		UPDATE dbo.[tmpKIVLeaveBalance] WITH(ROWLOCK,UPDLOCK) SET [Status] = 0  WHERE Requestid = @Requestid
	END
	
	EXEC [WorkingTimeRequest_WriteHistory] @RequestId

	COMMIT TRANSACTION;
	SELECT @ErrCode=0;
END TRY
BEGIN CATCH
	
	SELECT @ErrCode=100,@ErrMsg = 'Reset Status process failed'
	ROLLBACK TRANSACTION 
END CATCH;