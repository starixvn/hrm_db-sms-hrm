--USE HRM_SMS
GO
/****** Object:  StoredProcedure [dbo].[WorkingTimeRequest_ApproveRequest_7]    Script Date: 2013-11-07 9:55:07 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--DROP PROCEDURE [dbo].OverTimeRequest_ApproveDailySingleRequest

ALTER PROCEDURE [dbo].OverTime_ApproveSingleRequest
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
Task: approve Overtime request form (type 8)
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
DECLARE @EmpId INT, @RequestType smallint, @Status tinyint, @FromDate datetime, @ToDate datetime,@TotalDay INT
DECLARE @VerifierId INT,@ApproverId int,@HRId  INT
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

IF (@RoleID=2 and ((@VerifierId <> @ProcessedBy and @bOnbehalf=1) or (@Status <>1)))
BEGIN
	SET @ErrCode = 101
	IF  @Status <>1
		SET @ErrMsg = 'This request have been approved or rejected.'
	ELSE IF @VerifierId <> @ProcessedBy
		SET @ErrMsg = 'You don''t have permission on this request.'
	RETURN
END

IF (@RoleID=3 and ((@ApproverId <> @ProcessedBy and @bOnbehalf=1) or (@Status not in (2) ) AND @VerifierId <> @ApproverId) )
BEGIN
	SET @ErrCode = 102
	IF  @Status not in (1,2,3)
		SET @ErrMsg = 'This request have been approved or rejected.'
	ELSE IF @ApproverId <> @ProcessedBy
		SET @ErrMsg = 'You don''t have permission on this request.'
	RETURN
END
	
--IF (@RoleID=6 and ((@HRId <> @ProcessedBy and @bOnbehalf=1) or (@Status not in (4) )))
IF (@RoleID=6 and ((@Status not in (4) )))
BEGIN
	SET @ErrCode = 103
	IF  @Status not in (4) 
		SET @ErrMsg = 'This request have been approved or rejected.'
	ELSE IF @HRId <> @ProcessedBy
		SET @ErrMsg = 'You don''t have permission on this request.'
	RETURN
END

BEGIN TRY
    BEGIN TRANSACTION AAA;
		BEGIN
			 IF @RoleID = 2  --Verifier
				BEGIN
					UPDATE OT
					SET OT.[Status] = 2 
					FROM [OTDailyRequest] OT WITH(ROWLOCK,UPDLOCK)
					WHERE RequestID = @RequestID

					UPDATE dbo.[OTMonthlyRequest] WITH(ROWLOCK,UPDLOCK)
					SET [CurrentStatus] = 2, -- approved
						VerifierId= @ProcessedBy,
						VerifiedDate= @ProcessedDate,
						VerifiedStatus=2
					WHERE RequestID = @RequestID

				END
			ELSE IF @RoleID = 3 --Approver
				BEGIN
					UPDATE OT
					SET OT.[Status] = 4 
					FROM [OTDailyRequest] OT WITH(ROWLOCK,UPDLOCK)
					WHERE RequestID = @RequestID

					UPDATE dbo.[OTMonthlyRequest] WITH(ROWLOCK,UPDLOCK)
					SET [CurrentStatus] = 4, -- approved
						ApproverId= @ProcessedBy,
						ApprovedDate= @ProcessedDate,
						ApprovedStatus=2 
					WHERE RequestID = @RequestID

					EXEC [dbo].[Overtime_SET_OTSum]
						@EmpId =@EmpId, 
						@Month =@Month,

						@ErrCode = @ErrCode OUTPUT,
						@ErrMsg = @ErrMsg  OUTPUT

				END
			ELSE IF @RoleID = 6 --HR
				BEGIN
					UPDATE OT
					SET OT.[Status] = 6 
					FROM [OTDailyRequest] OT WITH(ROWLOCK,UPDLOCK)
					WHERE RequestID = @RequestID

					UPDATE dbo.[OTMonthlyRequest] WITH(ROWLOCK,UPDLOCK)
					SET [CurrentStatus] = 6, -- approved
						HRId= @ProcessedBy,
						HRDate= @ProcessedDate,
						HRStatus=2 
					WHERE RequestID = @RequestID
				END
		END

	COMMIT TRANSACTION AAA;
	SELECT @ErrCode=0;
END TRY
BEGIN CATCH
	SELECT ERROR_MESSAGE()
	SELECT @ErrCode=100,@ErrMsg = 'Aprrove process failed'
	ROLLBACK TRANSACTION AAA;
END CATCH; 


-- write log
	Declare @LogSPData varchar(4000), @now datetime,@Description varchar(200)
	set @now=getdate()
	--Log general info
	Select @LogSPData = '<OverTimeRequest_ApproveRequest RequestID="'+ coalesce(cast(@RequestID as varchar(1000)),space(1)) + '" ' +
		'RoleID="'+ coalesce(cast(@RoleID as varchar(100)),space(1)) + '" ' +
		'ProcessedBy="'+ coalesce(cast(@ProcessedBy as varchar(100)),space(1)) + '" ' +
		'ProcessedDate="'+ coalesce(convert(varchar(10),@ProcessedDate, 111 ),space(1)) + '" ' +
		'ErrCode="'+ coalesce(cast(@ErrCode as varchar(50)),space(1)) + '" ' +
		'ErrMsg="'+ coalesce(cast(@ErrMsg as varchar(4000)),space(1)) + '" />'		

	SELECT @Description = 'Approve OT Single Request:' + coalesce(cast(@RequestID as varchar(1000)),space(1)) 

	EXEC dbo.Log_WriteLog
		@LogActionID = 14,
		@LogDate = @now,
		@Description = @Description,
		@TrackingValue = @LogSPData,
		@UserID = @ProcessedBy,
		@EmpID=@EmpId