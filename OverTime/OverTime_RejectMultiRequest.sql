--USE HRM_SMS
GO
/****** Object:  StoredProcedure [dbo].[WorkingTimeRequest_ApproveRequest_7]    Script Date: 2013-11-07 9:55:07 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--DROP PROCEDURE [dbo].OverTime_RejectSingleRequest

ALTER PROCEDURE [dbo].OverTime_RejectMultiRequest
	--@Month datetime,

	@ProcessedBy int,
	@ProcessedDate datetime,

	@RoleID INT,
	@bOnbehalf bit=0,

	@ListRequestID VARCHAR(4000),

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

--SELECT @Month = CONVERT(NVARCHAR(10),YEAR(@Month)) + '/' + CONVERT(NVARCHAR(10),MONTH(@Month)) + '/01'

IF 1=0 AND NOT (DAY(GETDATE()) BETWEEN 15 AND 25 )
BEGIN
	SET @ErrCode =105
	SET @ErrMsg = 'You could only reject on arrange day 15 to 25 every month.'
	RETURN;
END

IF OBJECT_ID('tempdb..#RequestID') IS NOT NULL
		DROP TABLE #RequestID

CREATE TABLE #RequestID (RequestID INT)

IF ISNULL(@ListRequestID,'') <>''
	INSERT INTO #RequestID  (RequestID)
	SELECT val FROM fnc_strSplit (@ListRequestID, ',')
	
IF NOT EXISTS(SELECT TOP 1 1 FROM #RequestID)
BEGIN
	SET @ErrCode =104
	SET @ErrMsg = 'Invalid parameter'
	RETURN;
END


DECLARE @Month datetime,@sEmpID VARCHAR(8000)=''
IF @RoleID IN (3,6)
BEGIN
	SELECT TOP 1 @Month = OT.[Month] 
		FROM dbo.OTMonthlyRequest OT WITH(NOLOCK)
			INNER JOIN  #RequestID tmp ON OT.RequestID = tmp.RequestID 

	SELECT @sEmpID = COALESCE(@sEmpID + ',', '') + convert(NVARCHAR(50),ISNULL(OT.EmpId,'')) 
				FROM dbo.OTMonthlyRequest OT WITH(NOLOCK)
					INNER JOIN  #RequestID tmp ON OT.RequestID = tmp.RequestID 
END

IF (@RoleID = 2)
	BEGIN
		DELETE tmp
		FROM #RequestID tmp
		INNER JOIN dbo.[OTMonthlyRequest] OT WITH(NOLOCK)
			ON OT.RequestID = tmp.RequestID 
				AND OT.CurrentStatus <> 1
	END
ELSE IF (@RoleID = 3)
	BEGIN
		DELETE tmp
		FROM #RequestID tmp
		INNER JOIN dbo.[OTMonthlyRequest] OT WITH(NOLOCK)
			ON OT.RequestID = tmp.RequestID 
				AND OT.CurrentStatus <> 2
	END
ELSE IF (@RoleID = 3)
	BEGIN
		DELETE tmp
		FROM #RequestID tmp
		INNER JOIN dbo.[OTMonthlyRequest] OT WITH(NOLOCK)
			ON OT.RequestID = tmp.RequestID 
				AND OT.CurrentStatus <> 4
	END
BEGIN TRY
    BEGIN TRANSACTION AAA;
			 IF @RoleID = 2  --Verifier
				BEGIN
					UPDATE OT
					SET OT.[Status] = 3
					FROM [OTDailyRequest] OT WITH(ROWLOCK,UPDLOCK)
						INNER JOIN  #RequestID tmp
						ON OT.RequestID = tmp.RequestID 

					UPDATE OT
					SET OT.[CurrentStatus] = 3,
						VerifierId= @ProcessedBy,
						VerifiedDate= @ProcessedDate,
						VerifiedStatus=3,
						NormalHours	=0 ,OffHours =0 ,	PublicHours=0 
					FROM [OTMonthlyRequest] OT WITH(ROWLOCK,UPDLOCK)
						INNER JOIN  #RequestID tmp
						ON OT.RequestID = tmp.RequestID 
				END
			ELSE IF @RoleID = 3 --Approver
				BEGIN
					UPDATE OT
					SET OT.[Status] = 5 
					FROM [OTDailyRequest] OT WITH(ROWLOCK,UPDLOCK)
						INNER JOIN  #RequestID tmp
						ON OT.RequestID = tmp.RequestID 

					UPDATE OT
					SET [CurrentStatus] = 5, -- approved
						ApproverId= @ProcessedBy,
						ApprovedDate= @ProcessedDate,
						ApprovedStatus=3 ,
						NormalHours	=0 ,OffHours =0 ,	PublicHours=0 
					FROM [OTMonthlyRequest] OT WITH(ROWLOCK,UPDLOCK)
						INNER JOIN  #RequestID tmp
						ON OT.RequestID = tmp.RequestID 
				END
			ELSE IF @RoleID = 6 --HR
				BEGIN
					UPDATE OT
					SET [CurrentStatus] = 7, -- approved
						ApproverId= @ProcessedBy,
						HRDate= @ProcessedDate,
						HRStatus=3 ,
						NormalHours	=0 ,OffHours =0 ,	PublicHours=0 
					FROM [OTMonthlyRequest] OT WITH(ROWLOCK,UPDLOCK)
						INNER JOIN  #RequestID tmp
						ON OT.RequestID = tmp.RequestID 
					
					UPDATE OT
					SET OT.[Status] = 7 
					FROM [OTDailyRequest] OT WITH(ROWLOCK,UPDLOCK)
						INNER JOIN  #RequestID tmp
						ON OT.RequestID = tmp.RequestID 

					EXEC [dbo].[Overtime_SET_OTSum]
						@EmpId =@sEmpID, 
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

DROP TABLE #RequestID


-- write log
	Declare @LogSPData varchar(4000), @now datetime,@Description varchar(200)
	set @now=getdate()
	--Log general info
	Select @LogSPData = '<OverTimeRequest_RejectRequest RequestID="'+ coalesce(cast(@ListRequestID as varchar(1000)),space(1)) + '" ' +
		'RoleID="'+ coalesce(cast(@RoleID as varchar(100)),space(1)) + '" ' +
		'ProcessedBy="'+ coalesce(cast(@ProcessedBy as varchar(100)),space(1)) + '" ' +
		'ProcessedDate="'+ coalesce(convert(varchar(10),@ProcessedDate, 111 ),space(1)) + '" ' +
		'ErrCode="'+ coalesce(cast(@ErrCode as varchar(50)),space(1)) + '" ' +
		'ErrMsg="'+ coalesce(cast(@ErrMsg as varchar(4000)),space(1)) + '" />'		

	SELECT @Description = 'Reject OT Multi Request:' + coalesce(cast(@ListRequestID as varchar(1000)),space(1)) 

	EXEC dbo.Log_WriteLog
		@LogActionID = 12,
		@LogDate = @now,
		@Description = @Description,
		@TrackingValue = @LogSPData,
		@UserID = @ProcessedBy,
		@EmpID=NULL