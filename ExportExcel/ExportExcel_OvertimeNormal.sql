--USE [HRM_SMS]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].ExportExcel_OvertimeNormal
	@EmpID INT=NULL,
	@Month datetime,
	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(200) = '' OUTPUT,
	@isDebug BIT=0
AS
/*
Created: Tom.Vo@2013-10-23
Task: Export Excel Overtime Normal
DB: HRM_SMS
Original: 

Revisions:  
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @fromDate NVARCHAR(100),@toDate NVARCHAR(100)
		
	SELECT @fromDate = CONVERT(VARCHAR(10),YEAR(@Month)) + '/' + CONVERT(VARCHAR(10),MONTH(@Month)) + '/01 00:00:00'
	SELECT @toDate = DATEADD(DAY,-1,DATEADD(Month,1,@fromDate))
 
	IF OBJECT_ID('tempdb..#CalendarDF') IS NOT NULL
		DROP TABLE #CalendarDF

	CREATE TABLE #CalendarDF(WorkDate datetime,[Enabled] BIT,IsDeleted BIT,IsHoliday BIT)

	WHILE (CONVERT(DATETIME,@fromDate)<=CONVERT(DATETIME,@toDate)) 
		BEGIN
			if (exists(select TOP 1 1 
				from dbo.Holiday WITH(NOLOCK) where @fromdate between FromDate and ToDate))

				INSERT INTO #CalendarDF(WorkDate,[Enabled],IsDeleted,IsHoliday) VALUES(@fromDate,1,0,1)
			ELSE
				INSERT INTO #CalendarDF(WorkDate,[Enabled],IsDeleted,IsHoliday) VALUES(@fromDate,1,0,0)

			SET @fromDate=CONVERT(VARCHAR(10),CONVERT(DATETIME,@fromDate)+1,111)+ ' 00:00:00'
		END

	SELECT @fromDate = CONVERT(VARCHAR(10),YEAR(@Month)) + '/' + CONVERT(VARCHAR(10),MONTH(@Month)) + '/01 00:00:00'

	IF OBJECT_ID('tempdb..#tmpOTDetail') IS NOT NULL
		DROP TABLE #tmpOTDetail

	CREATE TABLE #tmpOTDetail(
		EmpId INT,
		EmpCode NVARCHAR(200),
		fullname NVARCHAR(200),
		nickname NVARCHAR(100),
		Team NVARCHAR(100),
		Positions NVARCHAR(100) )

	-- process the days string to use in pivot
	DECLARE @i INT,@totalDays INT
	DECLARE @days VARCHAR(1000),@day100 VARCHAR(4000),@query NVARCHAR(4000),@cols VARCHAR(4000)
	DECLARE @Header VARCHAR(4000),@GroupBy VARCHAR(4000)

	SELECT  @i=1,@totalDays = DAY(@ToDate)
	SELECT @query='', @days='',@day100='',@cols = '',@Header=''
	
	WHILE (@i<=@totalDays)
	BEGIN
		SET @days= @days + ',[' + cast(@i as varchar(2)) + ']'
		SET @day100= @day100 + ',[' + cast(@i+100 as varchar(10)) + ']'
		SET @cols=@cols+ ',[' + cast(@i as varchar(2)) + ']'+ ',[' + cast(@i+100 as varchar(10)) + ']'
		SET @Header=@Header+ ',SUM([' + cast(@i as varchar(2)) + ']) ' + '[' + cast(@i as varchar(2)) + ']' + ',SUM([' + cast(@i+100 as varchar(10)) + '])' + '[' + cast(@i+100 as varchar(10)) + ']'
		SET @query=@query+'ALTER TABLE #tmpOTDetail ADD [' + cast(@i as varchar(2)) + '] VARCHAR(100) NULL' +CHAR(13)
		SET @query=@query+'ALTER TABLE #tmpOTDetail ADD [' + cast(@i+100  as varchar(10)) + '] VARCHAR(100) NULL' +CHAR(13)
		SET @i=@i+1	
	END
		
	SET @days=substring(@days,2, len(@days)-1)
	SET @day100=substring(@day100,2, len(@day100)-1)
	SET @cols=substring(@cols,2, len(@cols)-1)
	SET @Header=substring(@Header,2, len(@Header)-1)
	
	SET @Header='EmpId,EmpCode, fullname, nickname, Team,Positions,' +  @Header
	SET @GroupBy='EmpId,EmpCode, fullname, nickname, Team,Positions'

	IF @isDebug = 1 print @query
	EXECUTE sp_executesql @query
	
	SELECT day(tmp.workdate) d
		,day(tmp.workdate)+100 d100
		,g.[Rank], g.Code [Team]
		,e.Code EmpCode, nickname, fullname, e.EmpId
		,lk.Name [Positions]
		,CASE WHEN tmp.IsHoliday = 1 THEN ISNULL(ot.[PublicHours],0) ELSE ISNULL(ot.[NormalHours],0) END AS Nor
		,CASE WHEN tmp.IsHoliday = 1 THEN 0 ELSE ISNULL(ot.[OffHours],0) END Off_PH
	INTO #Calendar
	FROM #CalendarDF tmp  WITH (NOLOCK)
	LEFT JOIN [dbo].[OTDailyRequest] ot WITH (NOLOCK) ON tmp.WorkDate = ot.OvertimeDate AND (@EmpID IS NULL OR ot.EmpID = @EmpID)
	LEFT JOIN [dbo].EmployeeSummary es WITH (NOLOCK) ON ot.EmpID = es.EmpID 
	LEFT JOIN [dbo].employee e WITH(NOLOCK) ON e.EmpId = ot.EmpId
	LEFT JOIN dbo.LookupData lk  WITH(NOLOCK) ON e.JobTitleId=lk.Id and lk.LookupId = 1
	LEFT JOIN dbo.[Group] g WITH(NOLOCK) on g.groupid=e.groupid
	--WHERE es.IsLocal = 1

	IF @@ROWCOUNT = 0
		BEGIN
			SELECT @ErrCode = 100,@ErrMsg = 'No Record'
			RETURN
		END

	DECLARE @updTAX NVARCHAR(4000)='',@TotlTax NVARCHAR(4000)=''

	SELECT @updTAX ='UPDATE  #tmpOTDetail SET',
			@TotlTax ='UPDATE  tmpOTSum SET  Tax='

	SELECT @query='INSERT  INTO #tmpOTDetail (Team,' + @cols + ')' + CHAR(13)
	SELECT @query=@query + 'VALUES( '''','
	
	SELECT @totalDays = DAY(@ToDate),@i = 1

	while (@i<=@totalDays)
	begin
		IF Exists(SELECT TOP 1 1 FROM #CalendarDF tmp Where tmp.WorkDate = @fromDate AND IsHoliday = 1 )
			BEGIN
				SET @query = @query + '''PH'',''Tax'',' + CHAR(13)
				SET @updTAX=@updTAX+ ' [' + cast(DAY(@fromDate)+100 as varchar(10)) + ']= CASE WHEN ISNULL(CONVERT(DECIMAL(18,2),[' + cast(DAY(@fromDate) as varchar(2)) + ']),0.0) > 8 THEN CONVERT(DECIMAL(18,2),[' + cast(DAY(@fromDate) as varchar(2)) + '])-8.0 ELSE NULL END,' + CHAR(13)
				SET @TotlTax=@TotlTax + 'ISNULL(CONVERT(DECIMAL(18,2),[' + cast(DAY(@fromDate)+100 as varchar(10)) + ']),0.0) +'
			END
		ELSE
			SET @query = @query + '''Nor'',''Off'',' + CHAR(13)

		SET @fromDate=CONVERT(VARCHAR(10),CONVERT(DATETIME,@fromDate)+1,111)+ ' 00:00:00'
		set @i=@i+1	
	end 
		
	SELECT @fromDate = CONVERT(VARCHAR(10),YEAR(@Month)) + '/' + CONVERT(VARCHAR(10),MONTH(@Month)) + '/01 00:00:00'
	SELECT @query=LEFT(@query,LEN(@query)-2) + ')'
	
	IF @isDebug = 1 print @query
	EXECUTE sp_executesql @query

	SET @query = '
		INSERT INTO #tmpOTDetail (EmpId,EmpCode, fullname, nickname, Team,Positions,'+@cols+')
		SELECT '+ @Header + CHAR(13) + ' FROM (
			SELECT EmpId,EmpCode, fullname, nickname, Team,Positions,'+ @cols 
			+' FROM (
				SELECT Team,Positions,EmpId,EmpCode,nickname,fullname,d,d100,
				Nor,Off_PH

				FROM #Calendar  tmp WITH(NOLOCK)
			) ea
			PIVOT
			(
				SUM(Nor) FOR d IN (' + @days + ')' + 
			') AS pvt_d
			PIVOT
			(
				SUM(Off_PH) FOR d100 IN (' + @day100 + ')' + 
			') AS pvt_d
		) tbl WHERE EmpId IS NOT NULL
		GROUP BY ' + @GroupBy +'
		'

	IF @isDebug = 1 print @query
	EXECUTE sp_executesql @query 
	
	IF @updTAX <> 'UPDATE  #tmpOTDetail SET'
	BEGIN
		SET @updTAX = LEFT(@updTAX,LEN(@updTAX)-2) + CHAR(13) + 'WHERE EMPID IS NOT NULL'
		
		IF @isDebug = 1 print @updTAX
		EXECUTE sp_executesql @updTAX

	END
	
	CREATE TABLE #tmpOTSum(EmpId INT,Normal DECIMAL(18,1),Offday DECIMAL(18,1),Holiday DECIMAL(18,1),Tax DECIMAL(18,1))

	INSERT INTO #tmpOTSum(EmpId,Normal,Offday,Holiday)
	SELECT ot.EmpId
		,SUM(ISNULL(ot.[NormalHours],0)) AS Normal
		,SUM(ISNULL(ot.[OffHours],0)) Offday
		,SUM(ISNULL(ot.[PublicHours],0)) Holiday

	FROM [dbo].[OTDailyRequest] ot WITH (NOLOCK)
	WHERE OvertimeDate between @fromDate and @todate  AND (@EmpID IS NULL OR ot.EmpID = @EmpID)
	GROUP BY ot.EmpId
	--ORDER BY tmp.WorkDate	

	SELECT a.EmpId,
			SUM(CASE WHEN ISNULL(LeaveDay,0)=0 THEN 1 WHEN lt.IsCalculateWoking = 1 THEN 1 ELSE ISNULL(LeaveDay,0) END) TotalWorkDays,
			SUM(CASE WHEN a.LeaveTypeId = 25 AND ISNULL(LeaveDay,0)>0 THEN LeaveDay ELSE 0 END) Unpaidleave
	INTO #tmpAtt
	FROM dbo.EmployeeAttendance a WITH (NOLOCK) 
		LEFT JOIN dbo.LeaveType lt WITH(NOLOCK) ON a.LeaveDay = lt.LeaveTypeId
	WHERE a.attendancedate between @fromDate and @todate
			and (@EmpID IS NULL OR a.EmpID = @EmpID)
			and  isnull(Absence,0)=0
	GROUP BY a.EmpId

	IF @TotlTax <> 'UPDATE  tmpOTSum SET  Tax='
	BEGIN
		SET @TotlTax = LEFT(@TotlTax,LEN(@TotlTax)-2) + CHAR(13) 
		+ 'FROM #tmpOTSum tmpOTSum
			LEFT JOIN  #tmpOTDetail tmpOTDetail 
				ON tmpOTSum.EmpID = tmpOTDetail.EmpID
		WHERE tmpOTDetail.EMPID IS NOT NULL'
		
		IF @isDebug = 1 print @TotlTax
		EXECUTE sp_executesql @TotlTax

	END
	
	UPDATE #tmpOTSum
	SET Holiday = Holiday-ISNULL(Tax,0.0)

	SELECT @query='SELECT tmpOTDetail.Team,tmpOTDetail.Positions,
		tmpOTDetail.EmpId,tmpOTDetail.EmpCode,tmpOTDetail.Nickname,tmpOTDetail.Fullname,
		tmpAtt.TotalWorkDays,tmpAtt.Unpaidleave,
		tmpOTSum.Normal,tmpOTSum.Offday,tmpOTSum.Holiday,tmpOTSum.Tax,' +CHAR(13)
		+@cols
	 +' FROM #tmpOTDetail tmpOTDetail 
		LEFT JOIN #tmpOTSum tmpOTSum ON tmpOTDetail.EmpId = tmpOTSum.EmpId
		LEFT JOIN #tmpAtt tmpAtt ON tmpOTDetail.EmpId = tmpAtt.EmpId
		'
	
	IF @isDebug = 1 print @query
	EXECUTE sp_executesql @query 

	DROP TABLE #CalendarDF
	DROP TABLE #Calendar
	DROP TABLE #tmpOTDetail
	DROP TABLE #tmpOTSum
	SELECT @ErrCode = 0,@ErrMsg = ''

END

/*
declare @p14 int,@p3 int
declare @p15 nvarchar(200)
declare @fromtime datetime,@totime datetime

exec ExportExcel_OvertimeNormal @EmpID=4,@Month='2014-01-01 00:00:00',@isDebug = 1


*/