--USE HRM_SMS
GO
/****** Object:  StoredProcedure [dbo].[WorkingTimeRequest_ApproveRequest_7]    Script Date: 2013-11-07 9:55:07 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--DROP PROCEDURE [dbo].OverTime_RejectSingleRequest

ALTER PROCEDURE [dbo].OverTime_ResetSingleRequest
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
Task: Reset Status Overtime request form (type 8)
DB: HRM_SMS
Original: 

Revisions:
Param's Explanation:
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF @RoleID NOT IN (2,3,6)
BEGIN
	SELECT @ErrCode = 1000, @ErrMsg = 'You don''t have permission on this request.'
	RETURN
END

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
		,@Month =[Month]
FROM dbo.[OTMonthlyRequest] WITH(NOLOCK)
WHERE RequestID = @RequestID

IF @RoleID = 2 AND ((@VerifierId <> @ProcessedBy and @bOnbehalf=1) OR @Status NOT IN (2,3))
BEGIN
	SET @ErrCode = 102
	SET @ErrMsg = 'You could not reset the request.'

	RETURN
END
ELSE IF @RoleID = 3 AND ((@ApproverId <> @ProcessedBy and @bOnbehalf=1)  OR @Status NOT IN (4,5))
BEGIN
	SET @ErrCode = 103
	SET @ErrMsg = 'You could not reset the request.'

	RETURN
END
ELSE IF @RoleID = 6 AND @Status NOT IN (6,7)
BEGIN
	SET @ErrCode = 104
	SET @ErrMsg = 'You could not reset the request.'

	RETURN
END

DECLARE @NormalHours decimal(18,2), @OffHours decimal(18,2), @PublicHours decimal(18,2)

IF @Status IN (3,5,7)
BEGIN
	SELECT @NormalHours = SUM (NormalHours),
		@OffHours = SUM (OffHours),
		@PublicHours = SUM (PublicHours)
	FROM dbo.OTDailyRequest WITH(NOLOCK)
	WHERE RequestID = @RequestID 
END


BEGIN TRY
    BEGIN TRANSACTION AAA;
	
		IF @RoleID = 2  --Verifier
		BEGIN
			UPDATE OT
				SET OT.[Status] = 1 
				FROM [OTDailyRequest] OT WITH(ROWLOCK,UPDLOCK)
				WHERE RequestID = @RequestID

			IF @Status = 3
				UPDATE OTM
				SET [CurrentStatus] = 1, -- approved
					VerifierId= @ProcessedBy,
					VerifiedDate= @ProcessedDate,
					VerifiedStatus=1,
					NormalHours	=@NormalHours ,OffHours =@OffHours  ,	PublicHours=@PublicHours
				FROM dbo.[OTMonthlyRequest] OTM WITH(ROWLOCK,UPDLOCK)
				WHERE RequestID = @RequestID
			ELSE
				UPDATE OTM
				SET [CurrentStatus] = 1, -- approved
					VerifierId= @ProcessedBy,
					VerifiedDate= @ProcessedDate,
					VerifiedStatus=1
					--,NormalHours	=0 ,OffHours =0 ,	PublicHours=0 
				FROM dbo.[OTMonthlyRequest] OTM WITH(ROWLOCK,UPDLOCK)
				WHERE RequestID = @RequestID
		END
		ELSE IF @RoleID = 3 --Approver
			BEGIN
				IF @VerifierId <> @ApproverId
				BEGIN
					UPDATE OT
					SET OT.[Status] = 2 
					FROM [OTDailyRequest] OT WITH(ROWLOCK,UPDLOCK)
					WHERE RequestID = @RequestID

					IF @Status = 5
						BEGIN
							UPDATE dbo.[OTMonthlyRequest] WITH(ROWLOCK,UPDLOCK)
							SET [CurrentStatus] = 2, -- approved
								ApproverId= @ProcessedBy,
								ApprovedDate= @ProcessedDate,
								ApprovedStatus=1 ,
								NormalHours	=@NormalHours ,OffHours =@OffHours  ,	PublicHours=@PublicHours
							WHERE RequestID = @RequestID

						END
					ELSE
						BEGIN
							UPDATE dbo.[OTMonthlyRequest] WITH(ROWLOCK,UPDLOCK)
							SET [CurrentStatus] = 2, -- approved
								ApproverId= @ProcessedBy,
								ApprovedDate= @ProcessedDate,
								ApprovedStatus=1
							WHERE RequestID = @RequestID

							EXEC [dbo].[Overtime_SET_OTSum]
								@EmpId =@EmpId, 
								@Month =@Month,

								@ErrCode = @ErrCode OUTPUT,
								@ErrMsg = @ErrMsg  OUTPUT
						END
					END
					ELSE
					BEGIN
						UPDATE OT
							SET OT.[Status] = 1 
							FROM [OTDailyRequest] OT WITH(ROWLOCK,UPDLOCK)
							WHERE RequestID = @RequestID

						UPDATE OTM
							SET [CurrentStatus] = 1, -- approved
								VerifierId= @ProcessedBy,
								VerifiedDate= @ProcessedDate,
								VerifiedStatus=1,
								NormalHours	=@NormalHours ,OffHours =@OffHours  ,	PublicHours=@PublicHours
							FROM dbo.[OTMonthlyRequest] OTM WITH(ROWLOCK,UPDLOCK)
							WHERE RequestID = @RequestID
					END

			END
		ELSE IF @RoleID = 6 --HR
			BEGIN
				UPDATE OT
				SET OT.[Status] = 4 
				FROM [OTDailyRequest] OT WITH(ROWLOCK,UPDLOCK)
				WHERE RequestID = @RequestID

				IF @Status = 7
					BEGIN					
						UPDATE dbo.[OTMonthlyRequest] WITH(ROWLOCK,UPDLOCK)
						SET [CurrentStatus] = 4, -- approved
							HRId= @ProcessedBy,
							HRDate= @ProcessedDate,
							HRStatus=1 ,
							NormalHours	=@NormalHours ,OffHours =@OffHours  ,	PublicHours=@PublicHours
						WHERE RequestID = @RequestID
							
						EXEC [dbo].[Overtime_SET_OTSum]
							@EmpId =@EmpId, 
							@Month =@Month,

							@ErrCode = @ErrCode OUTPUT,
							@ErrMsg = @ErrMsg  OUTPUT

					END
				ELSE
					UPDATE dbo.[OTMonthlyRequest] WITH(ROWLOCK,UPDLOCK)
					SET [CurrentStatus] = 4, -- approved
						HRId= @ProcessedBy,
						HRDate= @ProcessedDate,
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


-- write log
	Declare @LogSPData varchar(4000), @now datetime,@Description varchar(200)
	set @now=getdate()
	--Log general info
	Select @LogSPData = '<OverTimeRequest_ResetRequest RequestID="'+ coalesce(cast(@RequestID as varchar(1000)),space(1)) + '" ' +
		'RoleID="'+ coalesce(cast(@RoleID as varchar(100)),space(1)) + '" ' +
		'ProcessedBy="'+ coalesce(cast(@ProcessedBy as varchar(100)),space(1)) + '" ' +
		'ProcessedDate="'+ coalesce(convert(varchar(10),@ProcessedDate, 111 ),space(1)) + '" ' +
		'ErrCode="'+ coalesce(cast(@ErrCode as varchar(50)),space(1)) + '" ' +
		'ErrMsg="'+ coalesce(cast(@ErrMsg as varchar(4000)),space(1)) + '" />'		

	SELECT @Description = 'Reset OT Multil Request:' + coalesce(cast(@RequestID as varchar(1000)),space(1)) 

	EXEC dbo.Log_WriteLog
		@LogActionID = 16,
		@LogDate = @now,
		@Description = @Description,
		@TrackingValue = @LogSPData,
		@UserID = @ProcessedBy,
		@EmpID=@EmpId