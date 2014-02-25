USE HRM_SMS
GO
/****** Object:  StoredProcedure [dbo].[WorkingTimeRequest_ApproveRequest_7]    Script Date: 2013-11-07 9:55:07 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--DROP PROCEDURE [dbo].OverTimeRequest_ApproveDailySingleRequest

ALTER PROCEDURE [dbo].OverTime_ApproveMultiRequest
	@ProcessedBy int,
	@ProcessedDate datetime,
	@RoleID INT,
	@bOnbehalf bit=0,
	
	--@Month datetime,
	@ListRequestID varchar(8000)='',

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
ELSE IF (@RoleID = 6)
	BEGIN
		DELETE tmp
		FROM #RequestID tmp
		INNER JOIN dbo.[OTMonthlyRequest] OT WITH(NOLOCK)
			ON OT.RequestID = tmp.RequestID 
				AND OT.CurrentStatus <> 4
	END

IF NOT EXISTS(SELECT TOP 1 1 FROM #RequestID)
BEGIN
	SET @ErrCode =0
	SET @ErrMsg = ''
	RETURN;
END

DECLARE @Month datetime,@sEmpID VARCHAR(8000)=''

IF  @RoleID IN (3,6)
BEGIN
	SELECT TOP 1 @Month = OT.[Month] 
		FROM dbo.OTMonthlyRequest OT WITH(NOLOCK)
			INNER JOIN  #RequestID tmp ON OT.RequestID = tmp.RequestID 

	SELECT @sEmpID = COALESCE(@sEmpID + ',', '') + convert(NVARCHAR(50),ISNULL(OT.EmpId,'')) 
				FROM dbo.OTMonthlyRequest OT WITH(NOLOCK)
					INNER JOIN  #RequestID tmp ON OT.RequestID = tmp.RequestID 
END

BEGIN TRY
    BEGIN TRANSACTION AAA;
		BEGIN
			 IF @RoleID = 2  --Verifier
				BEGIN
					UPDATE OT
					SET OT.[Status] = 2 
					FROM [OTDailyRequest] OT WITH(ROWLOCK,UPDLOCK)
						INNER JOIN  #RequestID tmp
						ON OT.RequestID = tmp.RequestID 

					UPDATE OT
					SET OT.[CurrentStatus] = 2,
						VerifierId= @ProcessedBy,
						VerifiedDate= @ProcessedDate,
						VerifiedStatus=2
					FROM [OTMonthlyRequest] OT WITH(ROWLOCK,UPDLOCK)
						INNER JOIN  #RequestID tmp
						ON OT.RequestID = tmp.RequestID 
				END
			ELSE IF @RoleID = 3 --Approver
				BEGIN
					UPDATE OT
					SET OT.[Status] = 4 
					FROM [OTDailyRequest] OT WITH(ROWLOCK,UPDLOCK)
						INNER JOIN  #RequestID tmp
						ON OT.RequestID = tmp.RequestID 

					UPDATE OT
					SET [CurrentStatus] = 4, -- approved
						ApproverId= @ProcessedBy,
						ApprovedDate= @ProcessedDate,
						ApprovedStatus=2 
					FROM [OTMonthlyRequest] OT WITH(ROWLOCK,UPDLOCK)
						INNER JOIN  #RequestID tmp
						ON OT.RequestID = tmp.RequestID 
					
					EXEC [dbo].[Overtime_SET_OTSum]
						@EmpId =@sEmpID, 
						@Month =@Month,

						@ErrCode = @ErrCode OUTPUT,
						@ErrMsg = @ErrMsg  OUTPUT

				END
			ELSE IF @RoleID = 6 --HR
				BEGIN
					UPDATE OT
					SET OT.[Status] = 6 
					FROM [OTDailyRequest] OT WITH(ROWLOCK,UPDLOCK)
						INNER JOIN  #RequestID tmp
						ON OT.RequestID = tmp.RequestID 

					UPDATE OT
					SET [CurrentStatus] = 6, -- approved
						ApproverId= @ProcessedBy,
						HRDate= @ProcessedDate,
						HRStatus=2 
					FROM [OTMonthlyRequest] OT WITH(ROWLOCK,UPDLOCK)
						INNER JOIN  #RequestID tmp
						ON OT.RequestID = tmp.RequestID 
				END
		END

	COMMIT TRANSACTION AAA;
	SELECT @ErrCode=0;
END TRY
BEGIN CATCH
	SELECT @ErrCode=100,@ErrMsg = 'Aprrove process failed'
	ROLLBACK TRANSACTION AAA;
END CATCH; 

DROP TABLE #RequestID