--USE HRM_SMS
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[WorkingTimeRequest_Insert_LeaveMultiRequest]
	@EmpId int, 
	@RequestType smallint,	

	@Remark nvarchar(2000)=NULL,	
	@FromDate datetime=NULL, 
	@ToDate datetime=NULL, 
	@LeaveTypeID int=NULL, 
	@TotalDays numeric(5,1)=NULL,

	@CreatedDate datetime=NULL,
	@CreatedBy int=NULL,

	@VerifierId  int=NULL,
    @ApproverId  int=NULL,
    @HRId  int=NULL,

	@RefNo nvarchar(200)='',
	@ListDetail varchar(4000),--OnDate1,ShiftID1,LeaveType1,IsHalfDay1,FromTime1,ToTime1@OnDate2,ShiftID2,LeaveType2,IsHalfDay2,FromTime2,ToTime2@..@OnDaten,ShiftIDn,LeaveTypen,IsHalfDayn,FromTimen,ToTimen
	
	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(200) = '' OUTPUT	
AS
/*
Created: Tom.Vo@2013-11-11
Task: insert a Leave mutilple request form
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
	- @ListDetail: '<ROOT><LeaveRequestDetail OnDate='{20130101}' ShiftID='{1}' LeaveType={2} IsHalfDay={0} WorkType={0} FromTime={20130101 00:00:01} ToTime={20130101 00:00:01}></LeaveRequestDetail></ROOT>'
	- @WorkType :
			1. off
			2. leave
			3. work
*/
SET NOCOUNT ON;
DECLARE @TotalDays_tmp numeric(5,1),@isHalfDay BIT

SET @isHalfDay = CASE  WHEN @TotalDays = 0.5 THEN 1 ELSE 0 END

SET @TotalDays_tmp = @TotalDays

SET @CreatedDate = ISNULL(@CreatedDate,GETDATE())

IF YEAR(@FromDate) <> YEAR(@ToDate) 
BEGIN
	SET @ErrCode =103
	SET @ErrMsg = 'Do not create reqest cross period.'
	RETURN;
END

IF (@RequestType IN (6) AND 
	(@FromDate IS NULL OR @ToDate IS NULL OR @LeaveTypeID IS NULL 
		OR ISNULL(@TotalDays,0) < 0 )
	)
BEGIN
	SET @ErrCode =104
	SET @ErrMsg = 'Leave request has the invalid parameter'
	RETURN;
END

DECLARE @IsTopManager BIT,@IsLocal  BIT
SELECT TOP 1 @IsTopManager = IsTopManager,@IsLocal=IsLocal from dbo.EmployeeSummary WITH(NOLOCK) WHERE EmpId = @EmpId

IF ((@ApproverId IS NULL OR @VerifierId IS NULL) AND @IsTopManager = 0)
BEGIN
	SET @ErrCode =105
	SET @ErrMsg = 'Invalid parameter'
	RETURN;
END

DECLARE	@_FromDate NVARCHAR(100), @_ToDate NVARCHAR(100)

SELECT @_FromDate = CONVERT(VARCHAR(10),@fromDate,111) + ' 00:00:00',
		@_ToDate = CONVERT(VARCHAR(10),@toDate,111) + ' 00:00:00'

CREATE TABLE #LeaveRequestDetail (OnDate DateTime,ShiftID	INT,LeaveType	INT,WorkType TINYINT,IsHalfDay BIT,FromTime DateTime,ToTime DateTime)
DECLARE @DocHandler INT

BEGIN TRY	
	EXEC sp_xml_preparedocument @DocHandler OUTPUT, @ListDetail

	IF DATEDIFF (DD,@_FromDate,@_ToDate)+1 <> (SELECT COUNT(1) FROM dbo.EmployeeCalendar WITH(NOLOCK)
						WHERE EmpID= @EmpID AND WorkDate BETWEEN @_FromDate AND @_ToDate )
		BEGIN
			EXEC [dbo].[EmployeeCalendar_Insert_ByLeaveRequest]
					@empid =@EmpID,
					@fromdate =@_FromDate, 
					@todate =@_ToDate
		END

	INSERT INTO #LeaveRequestDetail (OnDate,ShiftID,LeaveType,WorkType,IsHalfDay,FromTime,ToTime)
	SELECT Data.OnDate,ISNULL(Data.ShiftID,ec.ShiftId) ShiftID,Data.LeaveType,Data.WorkType,Data.IsHalfDay,Data.FromTime,Data.ToTime
	FROM OPENXML (@DocHandler, '/ROOT/LeaveRequestDetail',1) 
	WITH (	OnDate	DateTime,
			ShiftID	INT, 
			LeaveType	INT,
			IsHalfDay	BIT,
			WorkType	TINYINT,
			FromTime	DateTime,
			ToTime	DateTime) AS Data 
			LEFT JOIN dbo.EmployeeCalendar ec WITH(NOLOCK)
				ON ec.WorkDate = data.OnDate AND ec.EmpId = @EmpId 

	IF @@ROWCOUNT <> 0
		SELECT @TotalDays_tmp = SUM(CASE lrd.IsHalfDay WHEN 1 THEN 0.5 ELSE 1 END) 
		FROM dbo.EmployeeCalendar cl WITH(NOLOCK)
					INNER JOIN #LeaveRequestDetail lrd ON cl.WorkDate = lrd.OnDate
							WHERE EmpID= @EmpID AND WorkDate BETWEEN @_FromDate AND @_ToDate
							AND IsHoliday = 0 AND IsOffDay = 0 AND IsLeaveDay = 0
							AND lrd.WorkType =2
		IF @TotalDays_tmp IS NULL
			SELECT @TotalDays_tmp = SUM(CASE lrd.IsHalfDay WHEN 1 THEN 0.5 ELSE 1 END) 
				FROM  #LeaveRequestDetail lrd
				WHERE lrd.WorkType =2

	EXEC sp_xml_removedocument @DocHandler

END TRY
BEGIN CATCH
		print ERROR_MESSAGE ( ) 
		SELECT @ErrCode = 100, @ErrMsg = N'Create leave request for an employee failed.'
		Return
END CATCH;

IF EXISTS(SELECT TOP 1 1 FROM #LeaveRequestDetail 
			WHERE IsHalfDay=1
			GROUP BY OnDate
			Having Count(DISTINCT LeaveType)=1  AND COUNT(OnDate)>1
)
BEGIN
		SELECT @ErrCode = 101, @ErrMsg = N'Please check Leave Type on this request.'
		Return
END

IF NOT EXISTS(SELECT TOP 1 1 FROM #LeaveRequestDetail)
BEGIN
	SELECT @TotalDays_tmp = SUM(1) FROM dbo.EmployeeCalendar cl WITH(NOLOCK)
				WHERE EmpID= @EmpID AND WorkDate BETWEEN @_FromDate AND @_ToDate
				AND IsHoliday = 0 AND IsOffDay = 0 
				--AND ShiftId IS NOT NULL 
				AND IsLeaveDay = 0
	IF @isHalfDay = 1 AND ISNULL(@TotalDays_tmp,1) = 1 
		SET @TotalDays_tmp = 0.5
END

IF (ISNULL(@TotalDays_tmp,0) <=0)
	BEGIN
		SET @ErrCode =105
		SET @ErrMsg = 'Your leave days invalid.'
		RETURN;
	END

IF @TotalDays_tmp IS NOT NULL OR @TotalDays_tmp >0
	SET @TotalDays = @TotalDays_tmp 

IF @EmpId <> @CreatedBy
BEGIN
	IF NOT EXISTS (SELECT TOP 1 1
	FROM [dbo].[EmployeeSupervisor] sp WITH(NOLOCK)
	WHERE sp.OwnerId = @EmpId
		AND sp.EmpId = @CreatedBy
		AND sp.ActionType = 5
		AND sp.RequestType = 6	
		)
	BEGIN
		SET @ErrCode = 106
		SET @ErrMsg = 'You could not permision on this request.'
		RETURN;
	END
END

IF @IsTopManager = 0
BEGIN
	IF NOT EXISTS (SELECT TOP 1 1
	FROM [dbo].[EmployeeSupervisor] sp WITH(NOLOCK)
	WHERE sp.OwnerId = @VerifierId
		AND sp.EmpId = @EmpId
		AND sp.ActionType = 2
		AND sp.RequestType in (6)
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
		AND sp.RequestType in (6)
		)
	BEGIN
		SET @ErrCode = 109
		SET @ErrMsg = 'invalid parameter ApproverId.'
		RETURN;
	END
END

IF (@RequestType = 6) AND 
	(exists(select top 1 1 from dbo.WorkingTimeRequest r WITH (NOLOCK)
					Inner JOIN dbo.LeaveRequest l WITH(NOLOCK) ON r.RequestId = l.RequestId
					LEFT JOIN dbo.EmployeeCalendar c WITH(NOLOCK) ON c.WorkDate BETWEEN l.fromdate AND l.ToDate AND c.empid = l.EmpId
			where r.empid=@empid 
			AND r.RequestType=@RequestType
			AND CurrentStatus in (1,2,3,4,6)
			AND (
					(@TotalDays >= 1 AND 
						(CONVERT(VARCHAR(10),fromdate,111) BETWEEN CONVERT(VARCHAR(10),@fromdate,111) AND CONVERT(VARCHAR(10),@todate,111)  
						OR CONVERT(VARCHAR(10),todate,111) BETWEEN CONVERT(VARCHAR(10),@fromdate,111) AND CONVERT(VARCHAR(10),@todate,111)
						OR CONVERT(VARCHAR(10),@fromdate,111) BETWEEN CONVERT(VARCHAR(10),fromdate,111) AND CONVERT(VARCHAR(10),todate,111)
						OR CONVERT(VARCHAR(10),@todate,111) BETWEEN CONVERT(VARCHAR(10),fromdate,111) AND CONVERT(VARCHAR(10),todate,111))
					)
					OR
					(
						@TotalDays < 1 AND TotalDays >= 1 AND
						(CONVERT(VARCHAR(10),fromdate,111) BETWEEN CONVERT(VARCHAR(10),@fromdate,111) AND CONVERT(VARCHAR(10),@todate,111)  
						OR CONVERT(VARCHAR(10),todate,111) BETWEEN CONVERT(VARCHAR(10),@fromdate,111) AND CONVERT(VARCHAR(10),@todate,111)
						OR CONVERT(VARCHAR(10),@fromdate,111) BETWEEN CONVERT(VARCHAR(10),fromdate,111) AND CONVERT(VARCHAR(10),todate,111)
						OR CONVERT(VARCHAR(10),@todate,111) BETWEEN CONVERT(VARCHAR(10),fromdate,111) AND CONVERT(VARCHAR(10),todate,111))
					)
					OR
					(
						@TotalDays < 1 AND TotalDays < 1 AND c.LeaveTypeID2 IS NOT NULL AND
						((fromdate BETWEEN @fromdate AND @todate) 
						OR (todate BETWEEN @fromdate AND @todate) 
						OR (@fromdate BETWEEN fromdate AND todate) 
						OR (@todate BETWEEN fromdate AND todate))
					)
				)
	) 
	OR
		(SELECT COUNT(1) FROM dbo.WorkingTimeRequest r WITH (NOLOCK)
					Inner join dbo.LeaveRequest l WITH(NOLOCK) ON r.RequestId = l.RequestId
			WHERE r.empid=@empid 
			AND r.RequestType=@RequestType
			AND CurrentStatus IN (1,2,3,4,6)
			AND @TotalDays < 1
			AND TotalDays = 0.5
			AND (fromdate BETWEEN @_FromDate AND @_ToDate)
		) >=2 
	OR
		(SELECT COUNT(1) FROM dbo.WorkingTimeRequest r WITH (NOLOCK)
					Inner join dbo.LeaveRequest l WITH(NOLOCK) ON r.RequestId = l.RequestId
			WHERE r.empid=@empid 
			AND r.RequestType=@RequestType
			AND CurrentStatus IN (1,2,3,4,6)
			AND @TotalDays < 1
			AND TotalDays = 0.5
			AND (fromdate BETWEEN @FromDate AND @ToDate)
		) >=1
	)
BEGIN
	SET @ErrCode = 107
	SET @ErrMsg = 'There is another request in the same range'
	RETURN;
END

DECLARE @AnnualLeave decimal(18,2),@AnnualLeavePending decimal(18,2),@AnnualLeaveBalance decimal(18,2),@KIVLeave decimal(18,2),@KIVLeavePending decimal(18,2)
IF EXISTS(SELECT TOP 1 1 FROM #LeaveRequestDetail)
	SELECT @AnnualLeave = SUM(CASE cl.IsHalfDay WHEN 1 THEN 0.5 ELSE 1 END) 
	FROM #LeaveRequestDetail cl WITH(NOLOCK)
	INNER JOIN dbo.LeaveType l WITH(NOLOCK)  ON cl.LeaveType = l.LeaveTypeId
	WHERE  IsALDeduction = 1
ELSE IF (EXISTS(SELECT TOP 1 1 FROM dbo.LeaveType  WITH(NOLOCK) WHERE LeaveTypeID = @LeaveTypeID AND IsALDeduction = 1) )
	SELECT @AnnualLeave = @TotalDays

SELECT @AnnualLeave = ISNULL(@AnnualLeave ,0)

IF EXISTS(SELECT TOP 1 1 FROM #LeaveRequestDetail )
	SELECT @KIVLeave = SUM(CASE cl.IsHalfDay WHEN 1 THEN 0.5 ELSE 1 END) 
	FROM #LeaveRequestDetail cl WITH(NOLOCK)
	INNER JOIN dbo.LeaveType l WITH(NOLOCK)  ON cl.LeaveType = l.LeaveTypeId
	WHERE  l.Code = 'KIV'
ELSE IF (EXISTS(SELECT TOP 1 1 FROM dbo.LeaveType  WITH(NOLOCK) WHERE LeaveTypeID = @LeaveTypeID AND  Code = 'KIV') )
	SELECT @KIVLeave = @TotalDays

SELECT @KIVLeave = ISNULL(@KIVLeave ,0)

-- check the total day is not greater than annual leave balance
IF ( @AnnualLeave > 0)
BEGIN
	SELECT @AnnualLeavePending = SUM(TotalDays) FROM dbo.tmpLeaveBalance WITH(NOLOCK) WHERE  EmpID = @EmpID AND [Status] = 0 AND YEAR(@FromDate) = InYear
	SELECT @AnnualLeavePending = ISNULL(@AnnualLeavePending ,0)
	SELECT @AnnualLeaveBalance= [dbo].[fnc_getLeaveBalanceEffectedDay] (@FromDate ,@EmpID)
	--SELECT @AnnualLeaveBalance= AnnualLeaveBalance FROM EmployeeSummary  WITH(NOLOCK) WHERE EmpId = @EmpId)
	IF (@AnnualLeave+@AnnualLeavePending > @AnnualLeaveBalance)
	BEGIN
		SET @ErrCode =108
		SET @ErrMsg = 'You have not enough annual leave days to request'
		RETURN;
	END
	 IF @IsLocal = 1 AND MONTH(@FromDate) <= 7
		BEGIN
			SELECT @AnnualLeaveBalance= [dbo].fnc_getLeaveDeductDays (YEAR(@ToDate) ,@EmpID)
			IF @AnnualLeave+@AnnualLeavePending+@AnnualLeaveBalance  >  MONTH(@ToDate)+5
			BEGIN
				SET @ErrCode =109
				SET @ErrMsg = 'Local: maximum '+ CONVERT(NVARCHAR(10),MONTH(@ToDate)+5) +' days in the first ' + CONVERT(NVARCHAR(10),MONTH(@ToDate)) +' months'
				SET @ErrMsg = 'Sorry, your request cannot be created. You''re allowed to use maximum '+ CONVERT(NVARCHAR(10),MONTH(@ToDate)+5) +'  annual leave days in the first ' + CONVERT(NVARCHAR(10),MONTH(@ToDate)) +' month(s)'
				RETURN;
			END
		END
END	

-- check the total day is not greater than KIV leave balance
IF ( @KIVLeave >= 0)
BEGIN
	SELECT @KIVLeavePending = SUM(TotalDays) FROM dbo.[tmpKIVLeaveBalance] WITH(NOLOCK) WHERE  EmpID = @EmpID AND [Status] = 0
	SELECT @KIVLeavePending = ISNULL(@KIVLeavePending ,0)
	IF (@KIVLeave+@KIVLeavePending > (SELECT KeepInViewBalance FROM EmployeeSummary  WITH(NOLOCK) WHERE EmpId = @EmpId)
	)		
	BEGIN
		SET @ErrCode =111
		SET @ErrMsg = 'You have not enough Keep In View leave days to request'
		RETURN;
	END
	
END	

EXEC [dbo].WorkingTimeRequest_GetNewRefNoByRequestType 
	@RefNo =@RefNo output,
	@RequestType =6

BEGIN TRY

		INSERT INTO dbo.WorkingTimeRequest
		(	   [EmpId]
			  ,[RequestType]
			  ,[Remark]
			  ,[CurrentStatus]
			  ,[VerifierId]
			  ,[ApproverId]
			  ,[HRId]
			  ,[VerifiedStatus]
			  ,[ApprovedStatus]
			  ,[HRStatus]
			  ,[CreatedDate]
			  ,[CreatedBy]
		)
		VALUES
		(
			@EmpId, 
			@RequestType,	
			@Remark,
			CASE WHEN @IsTopManager=1 AND @VerifierId IS NOT NULL THEN 1 
				WHEN @IsTopManager=1 AND @ApproverId IS NOT NULL THEN 2 
				WHEN @IsTopManager=1 AND @ApproverId IS NULL THEN 4 
				ELSE 1 END, -- pending [CurrentStatus] as default
			@VerifierId,
			@ApproverId,
			@HRId,
			CASE WHEN @IsTopManager=1 AND @VerifierId IS NULL THEN 2 ELSE 1 END, -- pending [VerifiedStatus] as default
			CASE WHEN @IsTopManager=1 AND @ApproverId IS NULL THEN 1 ELSE 1 END, -- pending [ApprovedStatus] as default
			1, -- pending [HRStatus] as default
			@CreatedDate, 
			@CreatedBy
		)


		DECLARE @RequestId bigint

		SELECT @RequestId = cast(SCOPE_IDENTITY() as bigint)

		INSERT INTO [dbo].[LeaveRequest]
					([RequestId]
					,[EmpId]
					,[FromDate]
					,[ToDate]
					,[LeaveType]
					,[TotalDays]
					,[RefNo])
				VALUES
					(@RequestId,
					@EmpId,
					@FromDate,
					@ToDate,
					@LeaveTypeID,
					@TotalDays,
					@RefNo
					)
 
		 INSERT INTO [dbo].[LeaveRequestDetail]
				   ([RequestId]
				   ,[EmpId]
				   ,[OnDate]
				   ,[ShiftId]
				   ,[LeaveType]
				   ,[IsHalfDay]
				   ,[FromTime]
				   ,[ToTime]
				   ,WorkType)
		SELECT  @RequestId RequestId , @EmpId EmpId , rd.OnDate,ShiftID,LeaveType,IsHalfDay,FromTime,ToTime,WorkType
		FROM #LeaveRequestDetail rd
 
		EXEC [dbo].WorkingTimeRequest_SET_TmpLeaveBalance
			@Requestid = @Requestid ,
			@EmpID = @EmpID ,
			@TotalDays =@AnnualLeave 
		
		EXEC [dbo].WorkingTimeRequest_SET_TmpKIVLeaveBalance
			@Requestid = @Requestid ,
			@EmpID = @EmpID ,
			@TotalDays =@KIVLeave

	IF (@ApproverId IS NULL AND @VerifierId IS NULL AND @IsTopManager = 1)
	BEGIN
			EXEC [dbo].[WorkingTimeRequest_ApproveRequest_6]
					@RequestID =@RequestID,
					@EmpID =@EmpID,
					@ApprovedBy =@EmpID,
					@ApprovedDate =@CreatedDate ,
					@RoleID =3,
					@ErrCode = @ErrCode  OUTPUT,
					@ErrMsg  = @ErrMsg   OUTPUT
	END
	
	EXEC [WorkingTimeRequest_WriteHistory] @RequestId

	SELECT @ErrCode=0;
END TRY
BEGIN CATCH
	
		SELECT @ErrCode = 100, @ErrMsg = N'Create leave request for an employee failed.'
		DELETE dbo.WorkingTimeRequest WHERE RequestId = @RequestId
		DELETE dbo.[LeaveRequest] WHERE RequestId = @RequestId
		DELETE dbo.[LeaveRequestDetail] WHERE RequestId = @RequestId
		Return
END CATCH;

SET @ErrCode = 0

DROP TABLE #LeaveRequestDetail

SELECT @RequestId


