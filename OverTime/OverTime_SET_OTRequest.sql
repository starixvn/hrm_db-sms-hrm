--USE HRM_SMS
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Overtime_SET_OTRequest]
	@EmpId int, 
	@RequestType smallint=8,
	
	@Remark VARCHAR(8000)='',

	@ProcessedBy int,
	@ProcessedDate datetime=NULL,

	@VerifierId  int=NULL,
    @ApproverId  int=NULL,
    @HRId  int=NULL,

	@ListDetail VARCHAR(8000) ,

	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(200) = '' OUTPUT,
	@IsDebug  BIT=0
AS
/*
Created: Tom.Vo@2013-11-04
Task: insert Over time request form
DB: HRM_SMS
Original: 

Revisions:
Param's Explanation:
	@ListDetail:
		<Requests>
		 <Request
			OnDate="20130101"
			ShiftID="1"
			TimeIn="07:46"
			TimeOut=17:00"
			TotalHours="1"
			NormalHours="1"
			OffHours="1"
			PublicHours="1"
			Remark="ABC"
		  ></Request>
		</Requests>

*/
SET NOCOUNT ON;

DECLARE @IsTopManager BIT,@IsLocal  BIT,@CanOT BIT
SELECT TOP 1 @IsTopManager = IsTopManager,@IsLocal=IsLocal,@CanOT =CanOT  from dbo.EmployeeSummary WITH(NOLOCK) WHERE EmpId = @EmpId

IF @ProcessedDate IS NULL OR @ProcessedDate = ''
	SET @ProcessedDate =GETDATE()

IF (@CanOT = 0)
BEGIN
	SELECT @ErrCode = 100,@ErrMsg = 'You don''t have permission on this function.'
	RETURN
END

IF ((@ApproverId IS NULL OR @VerifierId IS NULL) AND @IsTopManager = 0)
BEGIN
	SET @ErrCode =102
	SET @ErrMsg = 'Invalid parameter'
	RETURN;
END

IF OBJECT_ID('tempdb..#Calendar') IS NOT NULL
		DROP TABLE #Calendar

CREATE TABLE #Calendar (OnDate DateTime,ShiftID	INT,TimeIn	NVARCHAR(100),[TimeOut] NVARCHAR(100),
		TotalHours  Decimal(18,2),NormalHours Decimal(18,2),OffHours Decimal(18,2),
		PublicHours Decimal(18,2),Remark varchar(1000),
		IsOffDay BIT,TotalShiftHours  Decimal(18,2),TotalWorkHours  Decimal(18,2))

DECLARE @DocHandler INT

BEGIN TRY
	EXEC sp_xml_preparedocument @DocHandler OUTPUT, @ListDetail

	INSERT INTO #Calendar (OnDate,ShiftID,TimeIn,[TimeOut],TotalHours,NormalHours,OffHours,PublicHours,Remark)
	SELECT OnDate,ShiftID,TimeIn,[TimeOut],TotalHours,NormalHours,OffHours,PublicHours,Remark
	FROM OPENXML (@DocHandler, '/Requests/Request',1) 
	WITH (	OnDate DateTime,
			ShiftID	INT,
			TimeIn	NVARCHAR(100),
			[TimeOut] NVARCHAR(100),
			TotalHours Decimal(18,2),
			NormalHours Decimal(18,2),
			OffHours Decimal(18,2),
			PublicHours Decimal(18,2),
			Remark varchar(1000)
		) AS Data

	EXEC sp_xml_removedocument @DocHandler
END TRY
BEGIN CATCH
		SELECT @ErrCode = 101, @ErrMsg = N'Create overtime request for an employee failed.'
		Return
END CATCH;

IF NOT EXISTS(SELECT TOP 1 1 FROM #Calendar)
BEGIN
	SET @ErrCode =103
	SET @ErrMsg = 'Invalid parameter'
	RETURN;
END

IF @IsTopManager = 0
BEGIN
	IF NOT EXISTS (SELECT TOP 1 1
	FROM [dbo].[EmployeeSupervisor] sp WITH(NOLOCK)
	WHERE sp.OwnerId = @VerifierId
		AND sp.EmpId = @EmpId
		AND sp.ActionType = 2
		AND sp.RequestType in (8)	
		)
	BEGIN
		SET @ErrCode = 108
		SET @ErrMsg = 'invalid parameter verifierid.'
		RETURN;
	END
	IF NOT EXISTS (SELECT TOP 1 1
	FROM [dbo].[EmployeeSupervisor] sp WITH(NOLOCK)
	WHERE sp.OwnerId = @ApproverId
		AND sp.EmpId = @EmpId
		AND sp.ActionType = 3
		AND sp.RequestType in (8)
		)
	BEGIN
		SET @ErrCode = 109
		SET @ErrMsg = 'invalid parameter ApproverId.'
		RETURN;
	END
END

UPDATE cl 
SET cl.TotalShiftHours = ISNULL(s.TotalHours,0)
	,cl.TotalWorkHours = ISNULL(at.TotalWorkHours,0)
	,cl.IsOffDay = CASE WHEN ec.IsHoliday=1 THEN 1 WHEN ec.IsOffDay = 1 AND ec.IsKeepInView = 0 THEN 1 ELSE 0 END
FROM #Calendar cl 
	INNER JOIN dbo.Shift s WITH(NOLOCK) ON cl.ShiftID = s.ShiftID
	INNER JOIN dbo.EmployeeCalendar ec WITH(NOLOCK) ON ec.WorkDate = cl.OnDate AND ec.EmpId = @EmpId
	INNER JOIN dbo.EmployeeAttendance at WITH(NOLOCK) ON at.AttendanceDate = cl.OnDate AND ec.EmpId = @EmpId

SELECT TOP 1 @ErrMsg = CONVERT(NVARCHAR(10),ONDATE,111)
					FROM #Calendar cl  WITH(NOLOCK) 
						WHERE  ( (cl.TotalHours - (cl.TotalWorkHours - cl.TotalShiftHours)< NormalHours+OffHours+PublicHours) AND cl.IsOffDay = 0 )
							OR ( (cl.TotalHours < NormalHours+OffHours+PublicHours) AND cl.IsOffDay = 1 )
--IF @IsDebug = 1  PRINT @ErrMsg
--IF (ISNULL(@ErrMsg,'')	<> '')
--BEGIN
--	SET @ErrCode =104
--	SET @ErrMsg = 'Invalid parameter. Please correct TotalHours values ON ' + @ErrMsg + '.'
--	RETURN;
--END
--ELSE 
	SET @ErrMsg=''

DECLARE @RequestId bigint,@Month DATETIME,@CurrentStatus INT

SELECT TOP 1 @Month =  MAX(ot.OnDate)
FROM #Calendar ot

SELECT @Month = CASE WHEN DAY(@Month) BETWEEN 10 AND 31 THEN DATEADD(MONTH,1,@Month) ELSE @Month  END
SELECT @Month =CONVERT(VARCHAR(10),YEAR(@Month)) + '/' + CONVERT(VARCHAR(10),MONTH(@Month)) + '/01 00:00:00'

IF 1=0 AND (MONTH(@Month) <MONTH(GETDATE()) OR (MONTH(@Month) =MONTH(GETDATE()) AND DAY(@Month) >14) )
BEGIN
	SET @ErrCode =104
	SET @ErrMsg = 'You can input OT hours before KO Date in the current month.'
	RETURN;
END

SELECT TOP 1 @RequestId = OT.RequestId,@CurrentStatus = OT.[CurrentStatus]
	FROM dbo.[OTMonthlyRequest] OT WITH(NOLOCK)
	WHERE [Month] = @Month AND OT.EmpId = @EmpId
	 
IF @CurrentStatus not in (1,3,5,7)
BEGIN
	SET @ErrCode =104
	SET @ErrMsg = 'The Status of this Request is not pending.'
	RETURN;
END

IF @RequestId IS NULL 
BEGIN
	INSERT INTO [dbo].[OTMonthlyRequest] (
		   [Month]
		  ,[EmpId]
		  ,[NormalHours]
		  ,[OffHours]
		  ,[PublicHours]
		  ,[CurrentStatus]
		  ,[VerifierId]
		  ,[ApproverId]
		  ,[HRId]
		  ,[VerifiedStatus]
		  ,[ApprovedStatus]
		  ,[HRStatus]
		  ,CreatedBy
		  ,CreatedDate
		)
	SELECT @Month,@EmpId,
			SUM(ISNULL([NormalHours],0)),SUM(ISNULL([OffHours],0)),SUM(ISNULL([PublicHours],0)),
			1 [CurrentStatus],@VerifierId,@ApproverId,@HRId,
			CASE WHEN @IsTopManager=1 AND @ApproverId IS NULL THEN 2 ELSE 1 END, -- pending [VerifiedStatus] as default
			CASE WHEN @IsTopManager=1 AND @VerifierId IS NULL THEN 2 ELSE 1 END, -- pending [ApprovedStatus] as default
			1, -- pending [HRStatus] as default
			@ProcessedBy,
			@ProcessedDate
		FROM #Calendar rd

	SELECT @RequestId = cast(SCOPE_IDENTITY() as bigint)
END
ELSE
BEGIN
		UPDATE OT
		SET 	
				OT.[CurrentStatus]=CASE WHEN @IsTopManager=1 AND @VerifierId IS NOT NULL THEN 1 
						WHEN @IsTopManager=1 AND @ApproverId IS NOT NULL THEN 2 
						WHEN @IsTopManager=1 AND @ApproverId IS NULL THEN 4 
						ELSE 1 END,
				OT.VerifierId = @VerifierId,
				OT.[VerifiedStatus]=CASE WHEN @IsTopManager=1 AND @VerifierId IS NULL THEN 2 ELSE 1 END, -- pending [VerifiedStatus] as default
				OT.ApproverId = @ApproverId,
				OT.[ApprovedStatus]=CASE WHEN @IsTopManager=1 AND @ApproverId IS NULL THEN 2 ELSE 1 END, -- pending [ApprovedStatus] as default
				OT.HRId = @HRId,
				OT.ModifiedBy = @ProcessedBy,
				OT.ModifiedDate = @ProcessedDate,
				OT.[NormalHours] = rd.[NormalHours],
				OT.[OffHours] = rd.[OffHours],
				OT.[PublicHours]=rd.[PublicHours]
		FROM [OTMonthlyRequest]  OT WITH(ROWLOCK,UPDLOCK) ,
			( SELECT SUM(ISNULL(rd.[NormalHours],0)) [NormalHours],
					SUM(ISNULL(rd.[OffHours],0)) [OffHours],
					SUM(ISNULL(rd.[PublicHours],0)) [PublicHours] FROM #Calendar  rd
			)rd
		WHERE RequestId = @RequestId

		DELETE  dbo.[OTDailyRequest] WITH(ROWLOCK,UPDLOCK)
			WHERE EmpId = @EmpId AND [RequestId] = @RequestId

END

INSERT INTO [dbo].[OTDailyRequest]
			([OvertimeDate]
			,[EmpId]
			,[RequestId]
			,[Schedule]
			,[TimeIn]
			,[TimeOut]
			,[TotalHours]
			,[NormalHours]
			,[OffHours]
			,[PublicHours]
			,[Remark]
			,[Status]
			,[CreatedBy]
			,[CreatedDate]			
			,[IsUpdated])
SELECT OnDate [OvertimeDate]
			,@EmpId [EmpId]
			,@RequestId [RequestId]
			,ShiftID [Schedule]
			,CONVERT(NVARCHAR(100),OnDate,111) + ' ' +  [TimeIn] + ':00' [TimeIn]
			,CONVERT(NVARCHAR(100),OnDate,111) + ' ' +  [TimeOut] + ':00' [TimeOut]
			,[TotalHours]
			,[NormalHours]
			,[OffHours]
			,[PublicHours]
			,[Remark]
			,1 [Status]
			,@ProcessedBy [CreatedBy]
			,@ProcessedDate [CreatedDate]
			,0 [IsUpdated]
FROM #Calendar rd
	WHERE OnDate IS NOT NULL AND [TimeIn] IS NOT NULL AND [TimeOut] IS NOT NULL	

 IF @@ERROR <> 0 
	BEGIN
		DELETE  dbo.[OTDailyRequest] WHERE RequestId = @RequestId
		DELETE  dbo.[OTMonthlyRequest] WHERE RequestId = @RequestId
		SELECT @ErrCode = 101, @ErrMsg = N'Create overtime request for an employee failed.'
	END
ELSE 
	SELECT @ErrCode=0,@ErrMsg=''

DROP TABLE #Calendar

SELECT @RequestId