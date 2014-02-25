USE HRM_SMS
GO
/****** Object:  StoredProcedure [dbo].[WorkingTimeRequest_ApproveRequest_7]    Script Date: 2013-11-07 9:55:07 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--DROP PROCEDURE [dbo].OverTime_RejectSingleRequest

ALTER PROCEDURE [dbo].OverTime_RejectSingleRequest
	@RequestID bigint,
	@ProcessedBy int,
	@ProcessedDate datetime,
	@RoleID INT,
	@bOnbehalf bit=0,

	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(200) = '' OUTPUT
AS
/*
Created: Tom.Vo@2013-11-13
Task: Reject Overtime request form (type 8)
DB: HRM_SMS
Original: 

Revisions:
Param's Explanation:
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF 1=0 AND NOT (DAY(GETDATE()) BETWEEN 15 AND 25 )
BEGIN
	SET @ErrCode =105
	SET @ErrMsg = 'You could only reject on arrange day 15 to 25 every month.'
	RETURN;
END

-- get all request detail 
DECLARE @EmpId int, @RequestType smallint, @Status tinyint, @FromDate datetime, @ToDate datetime,@TotalDay INT
DECLARE @VerifierId int,@ApproverId int,@HRId  int
DECLARE @VerifiedStatus	INT,@ApprovedStatus	INT,@HRStatus INT
DECLARE @Month datetime

-- get employee and requestype of the request		
SELECT TOP 1 @EmpId = EmpId			,@Status = [CurrentStatus]
		,@VerifierId = VerifierId	,@VerifiedStatus = VerifiedStatus
		,@ApproverId = ApproverId	,@ApprovedStatus = ApprovedStatus
		,@HRId = HRId				,@HRStatus = HRStatus
		,@Month = [Month]
FROM dbo.[OTMonthlyRequest] WITH(NOLOCK)
WHERE RequestID = @RequestID

IF @RoleID = 2 AND ((@VerifierId <> @ProcessedBy and @bOnbehalf=1) OR @Status <> 1)
BEGIN
	SET @ErrCode = 102
	SET @ErrMsg = 'This request is not pending so it cannot be rejected.'

	RETURN
END
ELSE IF @RoleID = 3 AND ((@ApproverId <> @ProcessedBy and @bOnbehalf=1)  OR @Status <>2)
BEGIN
	SET @ErrCode = 103
	SET @ErrMsg = 'This request is not pending so it cannot be rejected.'

	RETURN
END
ELSE IF @RoleID = 6 AND @Status <>4
BEGIN
	SET @ErrCode = 104
	SET @ErrMsg = 'This request is not pending so it cannot be rejected.'

	RETURN
END

BEGIN TRY
    BEGIN TRANSACTION AAA;
		IF @RoleID = 2  --Verifier
		BEGIN
			UPDATE OT
			SET OT.[Status] = 3 
			FROM [OTDailyRequest] OT WITH(ROWLOCK,UPDLOCK)
			WHERE RequestID = @RequestID

			UPDATE dbo.[OTMonthlyRequest] WITH(ROWLOCK,UPDLOCK)
			SET [CurrentStatus] = 3, -- approved
				VerifierId= @ProcessedBy,
				VerifiedDate= @ProcessedDate,
				VerifiedStatus=3
				,NormalHours	=0 ,OffHours =0 ,	PublicHours=0 
			WHERE RequestID = @RequestID

		END
		ELSE IF @RoleID = 3 --Approver
			BEGIN
				UPDATE OT
				SET OT.[Status] = 5
				FROM [OTDailyRequest] OT WITH(ROWLOCK,UPDLOCK)
				WHERE RequestID = @RequestID

				UPDATE dbo.[OTMonthlyRequest] WITH(ROWLOCK,UPDLOCK)
				SET [CurrentStatus] = 5, -- approved
					ApproverId= @ProcessedBy,
					ApprovedDate= @ProcessedDate,
					ApprovedStatus=3 ,
					NormalHours	=0 ,OffHours =0 ,	PublicHours=0 
				WHERE RequestID = @RequestID

			END
		ELSE IF @RoleID = 6 --HR
			BEGIN
				UPDATE OT
				SET OT.[Status] = 7 
				FROM [OTDailyRequest] OT WITH(ROWLOCK,UPDLOCK)
				WHERE RequestID = @RequestID

				UPDATE dbo.[OTMonthlyRequest] WITH(ROWLOCK,UPDLOCK)
				SET [CurrentStatus] = 7, -- approved
					ApproverId= @ProcessedBy,
					HRDate= @ProcessedDate,
					HRStatus=3 ,
					NormalHours	=0 ,OffHours =0 ,	PublicHours=0 
				WHERE RequestID = @RequestID

				EXEC [dbo].[Overtime_SET_OTSum]
					@EmpId =@EmpId, 
					@Month =@Month,

					@ErrCode = @ErrCode OUTPUT,
					@ErrMsg = @ErrMsg  OUTPUT
			END

	COMMIT TRANSACTION AAA;
	SELECT @ErrCode=0;
END TRY
BEGIN CATCH
	SELECT @ErrCode=100,@ErrMsg = 'Aprrove process failed'
	ROLLBACK TRANSACTION AAA;
END CATCH; 
