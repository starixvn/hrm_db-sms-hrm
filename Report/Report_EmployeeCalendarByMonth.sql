--USE [HRM_SMS]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Report_EmployeeCalendarByMonth '2012/04/08'

ALTER PROCEDURE [dbo].[Report_EmployeeCalendarByMonth]
	@reportDate datetime,
	@empId int = null,
	@groupids varchar(1000) = '',
	@isDebug BIT=0
AS
/*
Created: Tom.Vo@2013-11-15
Task: view employee calendar by month
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
*/
SET NOCOUNT ON

DECLARE @Days varchar(1000), @cols varchar(2000), @totalDays int, 
		@fromDate datetime, @toDate datetime,
		@temptbl nvarchar(4000),@updtbl nvarchar(4000)

-- first day of month
set @fromDate= cast(YEAR(@reportDate) as varchar(4)) + '/' + cast(MONTH(@reportDate) as varchar(2)) + '/01'

-- last day of month
set @ToDate = dateadd(d,-1, dateadd(m,1,@fromdate))

set @totalDays = DAY(@ToDate)

CREATE TABLE #tmpCalendar(
	EmpId INT,
	fullname NVARCHAR(200),
	nickname NVARCHAR(100),
	Team NVARCHAR(100),
	Positions NVARCHAR(100) )

-- process the days string to use in pivot
declare @i int
select  @i=1, @days=''
select @temptbl='',@updtbl=''
while (@i<=@totalDays)
begin
	set @days= @days + ',[' + cast(@i as varchar(2)) + ']'
	set @temptbl=@temptbl+'ALTER TABLE #tmpCalendar ADD [' + cast(@i as varchar(2)) + '] NVARCHAR(100) NULL' +CHAR(13)
	set @temptbl=@temptbl+'ALTER TABLE #tmpCalendar ADD [' + cast(@i+100 as varchar(10)) + '] NVARCHAR(100) NULL' +CHAR(13)
	set @updtbl = @updtbl + ', tmp.[' + cast(@i+100 as varchar(10)) + '] = tblC.[' + cast(@i as varchar(10)) + ']'
	set @i=@i+1	
end

IF @isDebug = 1 print @temptbl
EXECUTE sp_executesql @temptbl

select  @days=substring(@days,2, len(@days)-1),@updtbl = RIGHT(@updtbl,LEN(@updtbl)-1)

set @cols='EmpId, fullname, nickname, Team,Positions,' +  @days

declare @LeaveTypeDefaultId as int 
select @LeaveTypeDefaultId = dbo.fnc_getLeaveTypeDefault()

DECLARE	@HolidayLeaveTypeCode varchar(50)
-- get leave type of holiday
select @HolidayLeaveTypeCode = code
from dbo.LeaveType (nolock)
where IsHoliday = 1

CREATE TABLE #GroupsList (GroupId TINYINT)
SET @groupids = ISNULL(@groupids,'')

IF @groupids <>''
	INSERT INTO #GroupsList (GroupId)
	SELECT val FROM fnc_strSplit (@groupids, ',')
ELSE
	BEGIN
		INSERT INTO #GroupsList (GroupId)
		SELECT GRoupID FROM [Group] g WITH (NOLOCK)
	END

CREATE TABLE #CalendarDF(WorkDate datetime,[Enabled] BIT,IsDeleted BIT)

WHILE (@fromDate<=@toDate) 
	BEGIN
		INSERT INTO #CalendarDF(WorkDate,[Enabled],IsDeleted) VALUES(@fromDate,1,0)
		SET @fromDate=CONVERT(VARCHAR(10),CONVERT(DATETIME,@fromDate)+1,111)+ ' 00:00:00'
	END
SELECT @fromDate = cast(YEAR(@reportDate) as varchar(4)) + '/' + cast(MONTH(@reportDate) as varchar(2)) + '/01'

SELECT g.[Rank], g.Code [Team], e.Code EmpCode, nickname, fullname, e.EmpId,  
		day(DF.workdate) d, 
		case 
				when s.code IS NOT NULL then s.code				
				when isLeaveDay=1 then lv.code + CASE  WHEN lv2.LeaveTypeId IS NOT NULL THEN '/' + lv2.code WHEN c.LeaveDay = 1 THEN '' WHEN c.LeaveDay = 0.5 THEN '½' ELSE '' END
				when isOffday=1 then 'OFF'
				when c.isHoliday=1 then @HolidayLeaveTypeCode
				WHEN esum.islocal =1 AND hld.HolidayName IS NOT NULL THEN @HolidayLeaveTypeCode				
				--when DATEPART(dw,DF.WorkDate)=1 AND es.IsDefaultSchedule = 1 THEN ISNULL(s_sun.code,'OFF')
				--when DATEPART(dw,DF.WorkDate)=2 AND es.IsDefaultSchedule = 1  THEN ISNULL(s_mon.code,'OFF')
				--when DATEPART(dw,DF.WorkDate)=3 AND es.IsDefaultSchedule = 1  THEN ISNULL(s_Tue.code,'OFF')
				--when DATEPART(dw,DF.WorkDate)=4 AND es.IsDefaultSchedule = 1  THEN ISNULL(s_wed.code,'OFF')
				--when DATEPART(dw,DF.WorkDate)=5 AND es.IsDefaultSchedule = 1  THEN ISNULL(s_thu.code,'OFF')
				--when DATEPART(dw,DF.WorkDate)=6 AND es.IsDefaultSchedule = 1  THEN ISNULL(s_fri.code,'OFF')
				--when DATEPART(dw,DF.WorkDate)=7 AND es.IsDefaultSchedule = 1  THEN ISNULL(s_sat.code,'OFF')
				
			end as Code,
		isOffday,
		CASE WHEN c.IsHoliday IS NOT NULL THEN c.IsHoliday			
			WHEN esum.islocal =1 AND hld.HolidayName IS NOT NULL THEN 1 ELSE 0 END IsHoliday,
		lk.Name	[Positions]
INTO #Calendar
FROM employee e WITH(NOLOCK) 
--	INNER JOIN dbo.EmployeeSummary es WITH(NOLOCK)	ON e.EmpId = es.EmpId
--	LEFT JOIN dbo.EmployeeDefaultShift eds WITH(NOLOCK)	ON eds.EmpId = es.EmpId AND es.IsDefaultSchedule = 1
	LEFT JOIN #CalendarDF DF  WITH (NOLOCK) on DF.[Enabled]= e.[Enabled] AND DF.IsDeleted= e.IsDeleted
	LEFT JOIN dbo.EmployeeCalendar c WITH(NOLOCK)	on DF.WorkDate=c.WorkDate AND e.EmpId = c.EmpId  AND c.IsPublic = 1
	LEFT JOIN dbo.LeaveType lv		WITH(NOLOCK)	on lv.LeaveTypeId=c.LeaveTypeId
	LEFT JOIN dbo.LeaveType lv2		WITH(NOLOCK)	ON lv2.LeaveTypeId=c.LeaveTypeId2
	LEFT JOIN dbo.Shift s			WITH(NOLOCK)	on s.shiftid= c.shiftid
	LEFT JOIN dbo.EmployeeSummary esum WITH (NOLOCK)  		ON esum.EmpId = e.EmpId AND esum.islocal = 1  
	LEFT JOIN dbo.Holiday hld WITH (NOLOCK)  			ON (hld.FromDate BETWEEN @fromDate AND @toDate			OR hld.ToDate BETWEEN @fromDate AND @toDate)			AND (DF.WorkDate BETWEEN hld.FromDate AND hld.ToDate )
	--LEFT JOIN dbo.Shift s_sun		WITH(NOLOCK)	ON s_sun.shiftid= eds.SunShift
	--LEFT JOIN dbo.Shift s_mon		WITH(NOLOCK)	ON s_mon.shiftid= eds.MonShift
	--LEFT JOIN dbo.Shift s_Tue		WITH(NOLOCK)	ON s_Tue.shiftid= eds.TueShift
	--LEFT JOIN dbo.Shift s_wed		WITH(NOLOCK)	ON s_wed.shiftid= eds.WedShift
	--LEFT JOIN dbo.Shift s_thu		WITH(NOLOCK)	ON s_thu.shiftid= eds.ThuShift
	--LEFT JOIN dbo.Shift s_fri		WITH(NOLOCK)	ON s_fri.shiftid= eds.FriShift
	--LEFT JOIN dbo.Shift s_sat		WITH(NOLOCK)	ON s_sat.shiftid= eds.SatShift
	LEFT JOIN dbo.LookupData lk  WITH(NOLOCK) ON e.JobTitleId=lk.Id and lk.LookupId = 1
	LEFT JOIN dbo.[Group] g WITH(NOLOCK) on g.groupid=e.groupid
WHERE DF.WorkDate between @fromDate and @toDate
	and (@empId is null or e.empid=@empId)
	and e.GroupId IN (SELECT GroupId FROM #GroupsList )

Declare @query nvarchar(4000)
set @query = '
	INSERT INTO #tmpCalendar ('+@cols+')
	SELECT '+ @cols 
	+' FROM (
		SELECT Team,EmpCode,nickname,fullname,EmpId,d,Code,Positions FROM #Calendar	WITH(NOLOCK)
	) ea
	PIVOT
	(
		MAX(Code) FOR d IN (' + @days + ')' + 
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
			SELECT c.Team,c.EmpCode,c.nickname,c.fullname,c.EmpId,c.d,c.Positions,
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
			 FROM #Calendar c  WITH (NOLOCK) 
					LEFT JOIN  Shift s WITH(NOLOCK) on s.Code= c.Code
					LEFT JOIN  LeaveType lt WITH(NOLOCK) on lt.Code= c.Code
		) ea
		PIVOT
		(
			MAX(Color) FOR d IN (' + @days + ')' + 
		') AS pvt ) tblC
		ON tblC.EmpId = tmp.EmpId 
		'

IF @isDebug = 1 print @query
EXECUTE sp_executesql @query

DROP TABLE #Calendar
DROP TABLE #GroupsList
DROP TABLE #CalendarDF

SELECT * FROM #tmpCalendar WITH(NOLOCK)
Order by Team,[Positions],fullname


DROP TABLE #tmpCalendar