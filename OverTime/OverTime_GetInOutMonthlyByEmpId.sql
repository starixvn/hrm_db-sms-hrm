--USE [HRM_SMS]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Overtime_GetInOutMonthlyByEmpId]
	@EmpID INT,
	@Month datetime,

	@groupids NVARCHAR(100)=NULL,
	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(200) = '' OUTPUT,
	@isDebug BIT=0
AS
/*
Created: Tom.Vo@2013-10-23
Task: Get Shift Scheduling
DB: HRM_SMS
Original: 

Revisions:  
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	IF EXISTS(SELECT TOP 1 1 FROM dbo.EmployeeSummary e WITH(NOLOCK) WHERE EmpId=@EmpID AND CanOT = 0)
	BEGIN
		SELECT @ErrCode = 100,@ErrMsg = 'You don''t have permission on this function.'
		RETURN
	END

	DECLARE @fromDate NVARCHAR(100),@toDate NVARCHAR(100)

	SELECT @toDate = @Month, @fromDate = DATEADD(month,-1,@Month)
	
	SELECT @fromDate = CONVERT(VARCHAR(10),YEAR(@fromDate)) + '/' + CONVERT(VARCHAR(10),MONTH(@fromDate)) + '/10 00:00:00',
		@toDate =  CONVERT(VARCHAR(10),YEAR(@toDate)) + '/' + CONVERT(VARCHAR(10),MONTH(@toDate)) + + '/09 00:00:00'
 
	IF OBJECT_ID('tempdb..#Calendar') IS NOT NULL
		DROP TABLE #Calendar

	CREATE TABLE #Calendar(WorkDate datetime,[Enabled] BIT,IsDeleted BIT)

	WHILE (CONVERT(DATETIME,@fromDate)<=CONVERT(DATETIME,@toDate)) 
		BEGIN
			INSERT INTO #Calendar(WorkDate,[Enabled],IsDeleted) VALUES(@fromDate,1,0)
			SET @fromDate=CONVERT(VARCHAR(10),CONVERT(DATETIME,@fromDate)+1,111)+ ' 00:00:00'
		END

	SELECT @fromDate = DATEADD(month,-1,@Month)
	SELECT @fromDate = CONVERT(VARCHAR(10),YEAR(@fromDate)) + '/' + CONVERT(VARCHAR(10),MONTH(@fromDate)) + '/10 00:00:00'

	IF OBJECT_ID('tempdb..#GroupsList') IS NOT NULL
		DROP TABLE #GroupsList
	CREATE TABLE #GroupsList (GroupId TINYINT)

	IF ISNULL(@groupids,'') <>''
	INSERT INTO #GroupsList (GroupId)
		SELECT g.val 
		FROM fnc_strSplit (@groupids, ',') AS g
	ELSE
		BEGIN
			INSERT INTO #GroupsList (GroupId)
			SELECT g.GRoupID FROM dbo.[Group] g WITH (NOLOCK)
		END

	DECLARE @SQL NVARCHAR(4000), @sWhere NVARCHAR(4000),@bWhere bit

	SELECT @sWhere = '',@bWhere = 0

	IF @EmpID IS NOT NULL
		SELECT @sWhere = @sWhere + CASE WHEN @bWhere = 1 THEN ' AND ' ELSE ' WHERE ' END 
					+ ' (e.EmpId = ' + CONVERT(NVARCHAR(10),@EmpID) +' )' + CHAR(13) 
					, @bWhere = 1

	IF ISNULL(@groupids,'') <> ''
		SELECT @sWhere = @sWhere + CASE WHEN @bWhere = 1 THEN ' AND ' ELSE ' WHERE ' END 
				+ ' ( e.GroupId IN (SELECT GroupId FROM #GroupsList) )' + CHAR(13) 
					, @bWhere = 1
	
	IF EXISTS(SELECT TOP (1) 1 FROM dbo.OTDailyRequest WITH(NOLOCK) WHERE (OvertimeDate BETWEEN @fromDate AND @toDate) AND EmpID = @EmpID)
		BEGIN
			SELECT tmp.WorkDate [OvertimeDate]
			  ,ISNULL(ot.[EmpId],@EmpID) AS [EmpId]
			  ,ot.[RequestId]
			  ,COALESCE(sc.ShiftId,scl.ShiftId,s.ShiftId) [ShiftId]
			  ,COALESCE(sc.TotalHours,scl.TotalHours,s.TotalHours) [TotalShiftHours]
			  ,COALESCE(sc.Code,scl.Code,s.Code) [Schedule]
			  ,CASE WHEN ot.[TimeIn] IS NULL OR s.ShiftId  IS NULL THEN 
						CASE WHEN ec.InFixed IS NULL THEN NULL ELSE CONVERT(VARCHAR(5),ec.InFixed,108) END
					ELSE CONVERT(VARCHAR(5),ot.[TimeIn],108) END [TimeIn]
			  ,CASE WHEN ot.[TimeOut] IS NULL OR s.ShiftId  IS NULL THEN 
						CASE WHEN ec.OutFixed IS NULL THEN NULL ELSE CONVERT(VARCHAR(5),ec.OutFixed,108) END
					ELSE CONVERT(VARCHAR(5),ot.[TimeOut],108) END [TimeOut]
			  ,CASE WHEN ec.TotalWorkHours IS NULL THEN NULL  ELSE 
													CONVERT(NVARCHAR(10),convert(int,ec.TotalWorkHours) ) +':'+	
													REPLICATE('0',2-LEN(CONVERT(NVARCHAR(10),convert(int,round((ec.TotalWorkHours%1)*60,0)))) )
													+CONVERT(NVARCHAR(10),convert(int,round((ec.TotalWorkHours%1)*60,0)))													
													END [TotalWorkHours_Time],
			CASE WHEN ec.TotalWorkHours IS NULL THEN NULL  ELSE ec.TotalWorkHours END TotalWorkHours 
			  ,ot.[NormalHours]
			  ,ot.[OffHours]
			  ,ot.[PublicHours]
			  ,ot.[Remark]
			  ,ot.[Status]
			  ,ot.[IsUpdated]
			  ,ecl.IsHoliday
			  ,ecl.IsOffDay
			  ,ecl.IsKeepInView
			  ,Case WHEN ecl.ChangeShiftId IS NULL THEN 0 ELSE 1 END IsChangeShift
			  ,esum.WorkingHours WorkingHoursContract
		  FROM #Calendar tmp
			LEFT JOIN [dbo].[OTDailyRequest] ot WITH (NOLOCK) ON tmp.WorkDate = ot.OvertimeDate AND ot.EmpID = @EmpID
			LEFT JOIN dbo.[Shift] s WITH (NOLOCK) ON s.ShiftId = ot.[Schedule]
			LEFT JOIN dbo.EmployeeAttendance ec WITH (NOLOCK)
				ON ec.AttendanceDate =  tmp.WorkDate  AND  ec.EmpId =@EmpID
			LEFT JOIN dbo.EmployeeCalendar ecl WITH(NOLOCK) 
				ON ecl.WorkDate = tmp.WorkDate AND ecl.EmpId = @EmpId
			LEFT JOIN dbo.[Shift] sc WITH (NOLOCK) ON sc.ShiftId = ec.ShiftId
			LEFT JOIN dbo.[Shift] scl WITH (NOLOCK) ON scl.ShiftId = ecl.ShiftId
			LEFT JOIN EmployeeSummary esum WITH (NOLOCK) ON esum.empID = @EmpID	
		  --WHERE (OvertimeDate BETWEEN @fromDate AND @toDate) 
		  ORDER BY tmp.WorkDate 
		END
	ELSE
		BEGIN
			SELECT @SQL ='SELECT ' + CHAR(13) 
				+'		tmp.WorkDate [OvertimeDate],' + CHAR(13)
				+'		' + CONVERT(NVARCHAR(10),@EmpID) +' AS [EmpId],' + CHAR(13) 
				+'		NULL [RequestId],' + CHAR(13) 
				+'		s.ShiftId [ShiftId],' + CHAR(13) 
				+'		s.TotalHours [TotalShiftHours],' + CHAR(13) 
				+'		s.Code [Schedule],' + CHAR(13) 
				+'		CASE WHEN ec.InFixed IS NULL THEN NULL ELSE CONVERT(VARCHAR(5),ec.InFixed,108) END [TimeIn],' + CHAR(13) 
				+'		CASE WHEN ec.OutFixed IS NULL  THEN NULL ELSE CONVERT(VARCHAR(5),ec.OutFixed,108) END [TimeOut],' + CHAR(13) 
				+'		CASE WHEN ec.TotalWorkHours  IS NULL THEN NULL  ELSE 
													CONVERT(NVARCHAR(10),convert(int,ec.TotalWorkHours) ) +'':''+	
													REPLICATE(''0'',2-LEN(CONVERT(NVARCHAR(10),convert(int,round((ec.TotalWorkHours%1)*60,0)))) )
													+CONVERT(NVARCHAR(10),convert(int,round((ec.TotalWorkHours%1)*60,0)))													
													END [TotalWorkHours_Time],' + CHAR(13) 
				+'		CASE WHEN ec.TotalWorkHours IS NULL THEN NULL  ELSE ec.TotalWorkHours END [TotalWorkHours],' + CHAR(13) 
				+'		NULL NormalHours,' + CHAR(13) 
				+'		NULL OffHours,' + CHAR(13) 
				+'		NULL PublicHours,'  + CHAR(13) 
				+'		NULL Remark,'  + CHAR(13) 
				+'		1 Status'  + CHAR(13) 
				+'		,ecl.IsHoliday'  + CHAR(13) 
				+'		,ecl.IsOffDay'  + CHAR(13) 
				+'		,ecl.IsKeepInView'  + CHAR(13) 
				+'		,Case WHEN ecl.ChangeShiftId IS NULL THEN 0 ELSE 1 END IsChangeShift'  + CHAR(13) 
				+'		,esum.WorkingHours WorkingHoursContract'  + CHAR(13) 
				+'		FROM dbo.Employee e WITH (NOLOCK)  ' + CHAR(13) 
				+'		INNER JOIN #Calendar tmp  ' + CHAR(13) 
				+'		ON e.[Enabled] = tmp.[Enabled] AND e.[IsDeleted] = tmp.[IsDeleted]' + CHAR(13) 
				+'		LEFT JOIN dbo.EmployeeAttendance ec WITH (NOLOCK)  ' + CHAR(13) 
				+'		ON ec.AttendanceDate =  tmp.WorkDate  AND  e.EmpId = ec.EmpId  ' + CHAR(13) 
				+'		LEFT JOIN dbo.EmployeeCalendar ecl WITH (NOLOCK)  ' + CHAR(13) 
				+'		ON ecl.WorkDate =  tmp.WorkDate  AND  ecl.EmpId = ec.EmpId  ' + CHAR(13) 
				+'		LEFT JOIN dbo.[Shift] s WITH (NOLOCK)' + CHAR(13) 
				+'		ON s.ShiftId = ec.ShiftId ' + CHAR(13) 
				+'		LEFT JOIN EmployeeSummary esum WITH (NOLOCK)  ' + CHAR(13) 
				+'		ON esum.empID = ' + CONVERT(NVARCHAR(10),@EmpID) + CHAR(13) 
				+	CASE WHEN @bWhere = 1 THEN 'WHERE ' + CHAR(13)  + REPLACE(@sWhere,'WHERE','') ELSE '' END
				+'		ORDER BY tmp.WorkDate' + CHAR(13)
			EXEC sp_executesql  @SQL 

			IF @isDebug = 1 PRINT @SQL 
		END
	DROP TABLE #GroupsList
	DROP TABLE #Calendar
	SELECT @ErrCode = 0,@ErrMsg = ''
END

/*
declare @p14 int,@p3 int
declare @p15 nvarchar(200)
declare @fromtime datetime,@totime datetime

SELECT @p15=N'',@p14=0
SET @fromtime='20131118'
SET @totime=@fromtime+7

exec [dbo].[Overtime_GetInOutMonthlyByEmpId]
	@EmpID =139,
	@Month = '20131101'
 ,@ErrCode = @p14 OUTPUT
 ,@ErrMsg = @p15 OUTPUT

SELECT @p3,@p14,@p15

*/