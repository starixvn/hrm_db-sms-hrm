--USE [HRM_SMS]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Report_EmployeeCalendarByMonth '2012/04/08'

ALTER PROCEDURE [dbo].[Report_EmployeeCalendarByWeekly]
	@empId int = null,
	@fromtime datetime, 
	@totime datetime, 
	@groupids varchar(1000) = '',
	@JobTitleId varchar(1000) = '',
	@isLocal bit = NULL,

	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(200) = '' OUTPUT,
	@isDebug BIT=0
AS
/*
Created: Tom.Vo@2013-11-15
Task: view employee calendar by weekly
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
*/

SET NOCOUNT ON;
DECLARE @fromDate NVARCHAR(100),@toDate NVARCHAR(100)

SELECT @fromDate = CONVERT(VARCHAR(10),@fromtime,111) + ' 00:00:00',
	@toDate = CONVERT(VARCHAR(10),@totime,111) + ' 00:00:00'

IF (DATEPART(dw,@fromDate)<>2 OR DATEPART(dw,@toDate)<>1 OR DATEDIFF(dd,@fromdate,@toDate)<>6)
BEGIN
	SELECT @ErrCode = 100,@ErrMsg = N'Parameter not correct.'
	RETURN
END

declare @LeaveTypeDefaultId as int 
select @LeaveTypeDefaultId = dbo.fnc_getLeaveTypeDefault()

DECLARE	@HolidayLeaveTypeCode varchar(50)
-- get leave type of holiday
select @HolidayLeaveTypeCode = code
from dbo.LeaveType (nolock)
where IsHoliday = 1

CREATE TABLE #GroupsList (GroupId TINYINT)
SET @groupids = ISNULL(@groupids,'')

IF @groupids<>''
	INSERT INTO #GroupsList (GroupId)
	SELECT val FROM fnc_strSplit (@groupids, ',')
ELSE
	BEGIN
		INSERT INTO #GroupsList (GroupId)
		SELECT GRoupID FROM [Group] g WITH (NOLOCK)
	END

CREATE TABLE #JobTitleList (JobTitleId TINYINT)

IF ISNULL(@JobTitleId,'')  <>''
	INSERT INTO #JobTitleList (JobTitleId)
	SELECT val FROM fnc_strSplit (@JobTitleId, ',')
ELSE
	BEGIN
		INSERT INTO #JobTitleList (JobTitleId)
		SELECT ID FROM  dbo.LookupData lk  WITH(NOLOCK) WHERE LookupId = 1
	END

CREATE TABLE #Calendar(WorkDate datetime,[Enabled] BIT,IsDeleted BIT)

WHILE (@fromDate<=@toDate) 
	BEGIN
		INSERT INTO #Calendar(WorkDate,[Enabled],IsDeleted) VALUES(@fromDate,1,0)
		SET @fromDate=CONVERT(VARCHAR(10),CONVERT(DATETIME,@fromDate)+1,111)+ ' 00:00:00'
	END
SET @fromDate = CONVERT(VARCHAR(10),@fromtime,111) + ' 00:00:00'

CREATE TABLE #tmpCalendar(
	EmpId INT,
	EmpCode NVARCHAR(200),
	fullname NVARCHAR(200),
	nickname NVARCHAR(100),
	Team NVARCHAR(100),
	Positions NVARCHAR(100) )

-- process the days string to use in pivot
declare @i int,@temptbl nvarchar(4000),@updtbl nvarchar(4000)
DECLARE @cols varchar(2000), @totalDays int

select  @i=1, @totalDays = 7
select @temptbl='',@updtbl=''

while (@i<=@totalDays)
begin
	set @temptbl=@temptbl+'ALTER TABLE #tmpCalendar ADD [' + cast(@i as varchar(2)) + '] NVARCHAR(100) NULL' +CHAR(13)
	set @temptbl=@temptbl+'ALTER TABLE #tmpCalendar ADD [' + cast(@i+100 as varchar(10)) + '] NVARCHAR(100) NULL' +CHAR(13)
	set @updtbl = @updtbl + ', tmp.[' + cast(@i+100 as varchar(10)) + '] = tblC.[' + cast(@i as varchar(10)) + ']'
	set @i=@i+1	
end
SET @updtbl = RIGHT(@updtbl,LEN(@updtbl)-1)

IF @isDebug = 1 print @temptbl
EXECUTE sp_executesql @temptbl

SELECT  e.EmpId,
		DATEPART(dw,tmp.WorkDate) [Weekday], 
		--day(tmp.workdate) d, 
		case 
				when isLeaveDay=1 then lv.code + CASE  WHEN lv2.LeaveTypeId IS NOT NULL THEN '/' + lv2.code WHEN c.LeaveDay = 1 THEN '' WHEN c.LeaveDay = 0.5 THEN '½' ELSE '' END
				when s.code IS NOT NULL then s.code
				when c.isHoliday=1 then @HolidayLeaveTypeCode
				WHEN esum.islocal =1 AND hld.HolidayName IS NOT NULL THEN @HolidayLeaveTypeCode
				when isOffday=1 then 'OFF'		
				--when DATEPART(dw,tmp.WorkDate)=1 AND es.IsDefaultSchedule = 1 THEN ISNULL(s_sun.code,'OFF')
				--when DATEPART(dw,tmp.WorkDate)=2 AND es.IsDefaultSchedule = 1  THEN ISNULL(s_mon.code,'OFF')
				--when DATEPART(dw,tmp.WorkDate)=3 AND es.IsDefaultSchedule = 1  THEN ISNULL(s_Tue.code,'OFF')
				--when DATEPART(dw,tmp.WorkDate)=4 AND es.IsDefaultSchedule = 1  THEN ISNULL(s_wed.code,'OFF')
				--when DATEPART(dw,tmp.WorkDate)=5 AND es.IsDefaultSchedule = 1  THEN ISNULL(s_thu.code,'OFF')
				--when DATEPART(dw,tmp.WorkDate)=6 AND es.IsDefaultSchedule = 1  THEN ISNULL(s_fri.code,'OFF')
				--when DATEPART(dw,tmp.WorkDate)=7 AND es.IsDefaultSchedule = 1  THEN ISNULL(s_sat.code,'OFF')

			end as Code,
		isOffday,
		CASE WHEN c.IsHoliday IS NOT NULL THEN c.IsHoliday			
			WHEN esum.islocal =1 AND hld.HolidayName IS NOT NULL THEN 1 ELSE 0 END IsHoliday,
		lk.Name	[Positions]
INTO #CalendarWeekLy
FROM dbo.Employee e WITH(NOLOCK)
	--INNER JOIN dbo.EmployeeSummary es WITH(NOLOCK)	ON e.EmpId = es.EmpId
	--LEFT JOIN dbo.EmployeeDefaultShift eds WITH(NOLOCK)	ON eds.EmpId = es.EmpId AND es.IsDefaultSchedule = 1
	INNER JOIN #Calendar tmp 	 WITH (NOLOCK)	ON e.[Enabled] = tmp.[Enabled] AND e.[IsDeleted] = tmp.[IsDeleted]
	LEFT JOIN dbo.LookupData lk		WITH(NOLOCK) 	ON e.JobTitleId=lk.Id and LookupId = 1
	LEFT JOIN dbo.EmployeeCalendar c WITH(NOLOCK)	ON  c.WorkDate =  tmp.WorkDate  AND e.empid=c.empid AND c.IsPublic = 1
	LEFT JOIN  dbo.LeaveType lv		WITH(NOLOCK) 	ON lv.LeaveTypeId=c.LeaveTypeId
	LEFT JOIN  dbo.LeaveType lv2	WITH(NOLOCK)	ON lv2.LeaveTypeId=c.LeaveTypeId2
	LEFT JOIN  dbo.Shift s			WITH(NOLOCK)	ON s.shiftid= c.shiftid
	LEFT JOIN dbo.EmployeeSummary esum WITH (NOLOCK)  		ON esum.EmpId = e.EmpId AND esum.islocal = 1  
	LEFT JOIN dbo.Holiday hld WITH (NOLOCK)  			ON (hld.FromDate BETWEEN @fromDate AND @toDate			OR hld.ToDate BETWEEN @fromDate AND @toDate)			AND (tmp.WorkDate BETWEEN hld.FromDate AND hld.ToDate )
	--LEFT JOIN  dbo.Shift s_sun		WITH(NOLOCK)	ON s_sun.shiftid= eds.SunShift
	--LEFT JOIN  dbo.Shift s_mon		WITH(NOLOCK)	ON s_mon.shiftid= eds.MonShift
	--LEFT JOIN  dbo.Shift s_Tue		WITH(NOLOCK)	ON s_Tue.shiftid= eds.TueShift
	--LEFT JOIN  dbo.Shift s_wed		WITH(NOLOCK)	ON s_wed.shiftid= eds.WedShift
	--LEFT JOIN  dbo.Shift s_thu		WITH(NOLOCK)	ON s_thu.shiftid= eds.ThuShift
	--LEFT JOIN  dbo.Shift s_fri		WITH(NOLOCK)	ON s_fri.shiftid= eds.FriShift
	--LEFT JOIN  dbo.Shift s_sat		WITH(NOLOCK)	ON s_sat.shiftid= eds.SatShift
	LEFT JOIN  dbo.[Group] g		WITH(NOLOCK) ON g.groupid=e.groupid 
	
	WHERE (@empId is null or e.empid=@empId)
	and (@groupids='' OR e.JobTitleId IN (SELECT JobTitleId FROM #JobTitleList ))
	and e.GroupId IN (SELECT GroupId FROM #GroupsList )	

Declare @query nvarchar(4000)
set @cols='EmpId, [2],[3],[4],[5],[6],[7],[1]'

set @query = '
	INSERT INTO #tmpCalendar ('+@cols+')
	SELECT '+ @cols 
	+' FROM (
		SELECT EmpId,Weekday,Code FROM #CalendarWeekLy	 WITH (NOLOCK)	
	) ea
	PIVOT
	(
		MAX(Code) FOR [Weekday] IN ([2],[3],[4],[5],[6],[7],[1])' + 
	') AS pvt'

IF @isDebug = 1 print @query
EXECUTE sp_executesql @query

set @query = '
	UPDATE tmp
		SET ' + @updtbl + '
	FROM #tmpCalendar  tmp
		INNER JOIN (
		SELECT '+ @cols + 
		' FROM ( 
			SELECT c.EmpId, c.[Weekday], 
				CASE WHEN c.isOffday = 1 THEN ''#F8F89C'' 
					WHEN c.IsHoliday = 1 THEN ''#F3AA4B''
					WHEN s.Color IS NOT NULL THEN s.Color
					WHEN lt.Color IS NOT NULL THEN lt.Color 
					WHEN c.Code IN (''OFF'') THEN ''#F8F89C''
					WHEN c.Code IN (''AL½'') THEN ''#C7F391''
					WHEN c.Code IN (''UPL½'') THEN ''#EACDED''
					WHEN c.Code IN (''WL½'') THEN ''#7CD3E9''
					WHEN c.Code IN (''BT½'') THEN ''#C1D6ED''
					WHEN c.Code LIKE (''%/%'') THEN ''#D4E5D5''
					ELSE ''''
					END AS Color
			 FROM #CalendarWeekLy c LEFT JOIN  Shift s WITH(NOLOCK) on s.Code= c.Code
					LEFT JOIN  LeaveType lt WITH(NOLOCK) on lt.Code= c.Code
		) ea
		PIVOT
		(
			MAX(Color) FOR [Weekday] IN ([2],[3],[4],[5],[6],[7],[1])' + 
		') AS pvt ) tblC
		ON tblC.EmpId = tmp.EmpId 
		'
		
IF @isDebug = 1 print @query
EXECUTE sp_executesql @query

IF @isLocal IS NULL
	SELECT tmp.EmpId, ee.Code EmpCode ,ee.fullname, ee.nickname,lk.Name [Positions], g.Name Team,[2],[102],[3],[103],[4],[104],[5],[105],[6],[106],[7],[107],[1],[101]--,es.IsLocal
	FROM #tmpCalendar  tmp WITH (NOLOCK)
		LEFT JOIN Employee ee WITH (NOLOCK) ON tmp.EmpId = ee.EmpId
		LEFT JOIN dbo.EmployeeSummary es  WITH (NOLOCK) ON tmp.EmpId = es.EmpId
		LEFT JOIN  dbo.[Group] g		WITH(NOLOCK) ON g.groupid=ee.groupid 
		LEFT JOIN dbo.LookupData lk		WITH(NOLOCK) 	ON ee.JobTitleId=lk.Id and LookupId = 1
	Order by Team,es.IsLocal desc,ee.Code
ELSE
	SELECT tmp.EmpId, ee.Code EmpCode ,ee.fullname, ee.nickname,lk.Name [Positions], g.Name Team,[2],[102],[3],[103],[4],[104],[5],[105],[6],[106],[7],[107],[1],[101]
	FROM #tmpCalendar  tmp  WITH (NOLOCK)
		INNER JOIN dbo.EmployeeSummary es  WITH (NOLOCK) ON tmp.EmpId = es.EmpId AND es.IsLocal = @isLocal
		LEFT JOIN Employee ee WITH (NOLOCK) ON tmp.EmpId = ee.EmpId
		LEFT JOIN  dbo.[Group] g		WITH(NOLOCK) ON g.groupid=ee.groupid 
		LEFT JOIN dbo.LookupData lk		WITH(NOLOCK) 	ON ee.JobTitleId=lk.Id and LookupId = 1
	Order by Team,ee.Code

DROP TABLE #CalendarWeekLy
DROP TABLE #Calendar
DROP TABLE #tmpCalendar
DROP TABLE #GroupsList

SELECT @ErrCode=0

