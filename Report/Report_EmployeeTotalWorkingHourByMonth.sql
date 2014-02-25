--USE [HRM_SMS]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Report_EmployeeCalendarByMonth '2012/04/08'

ALTER PROCEDURE [dbo].[Report_EmployeeTotalWorkingHourByMonth]
	@reportMonth datetime,
	@empId int = null,
	@groupids varchar(1000) = '',
	@isLocal bit = NULL,

	@isDebug BIT=0
AS
/*
Created: Tom.Vo@2013-11-15
Task: view employee Total Working Hour by month
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
*/
SET NOCOUNT ON

DECLARE @Days varchar(1000), @cols varchar(2000), @totalDays int, @fromDatetmp datetime,
		@temptbl nvarchar(4000),@updtbl nvarchar(4000),
		@FromDate datetime,
		@toDate datetime

-- first day of month
set @fromDate= cast(YEAR(@reportMonth) as varchar(4)) + '/' + cast(MONTH(@reportMonth) as varchar(2)) + '/01'

-- last day of month
set @ToDate = dateadd(d,-1, dateadd(m,1,@fromdate))

set @totalDays = DAY(@ToDate)

CREATE TABLE #tmpCalendar(
	EmpId INT,
	EmpCode NVARCHAR(200),
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
	set @i=@i+1	
end

IF @isDebug = 1 print @temptbl
EXECUTE sp_executesql @temptbl

select  @days=substring(@days,2, len(@days)-1)

set @cols='EmpId,EmpCode, fullname, nickname, Team,Positions,' +  @days

declare @LeaveTypeDefaultId as int 
select @LeaveTypeDefaultId = dbo.fnc_getLeaveTypeDefault()

DECLARE	@HolidayLeaveTypeCode varchar(50)
-- get leave type of holiday
select @HolidayLeaveTypeCode = code
from dbo.LeaveType (nolock)
where IsHoliday = 1

CREATE TABLE #GroupsList (GroupId TINYINT)
SET @groupids = ISNULL(@groupids,'')

IF ISNULL(@groupids,'') <>''
	INSERT INTO #GroupsList (GroupId)
	SELECT val FROM fnc_strSplit (@groupids, ',')
ELSE
	BEGIN
		INSERT INTO #GroupsList (GroupId)
		SELECT GRoupID FROM [Group] g WITH (NOLOCK)
	END

CREATE TABLE #CalendarDF(WorkDate datetime,[Enabled] BIT,IsDeleted BIT)
SELECT @fromDatetmp=@fromDate
WHILE (@fromDatetmp<=@toDate) 
	BEGIN
		INSERT INTO #CalendarDF(WorkDate,[Enabled],IsDeleted) VALUES(@fromDatetmp,1,0)
		SET @fromDatetmp=CONVERT(VARCHAR(10),CONVERT(DATETIME,@fromDatetmp)+1,111)+ ' 00:00:00'
	END
	
SELECT g.[Rank], g.Code [Team], e.Code EmpCode, nickname, fullname, e.EmpId,  
		day(DF.workdate) d, 
		CONVERT(NVARCHAR(10),convert(int,e_att.TotalWorkHours) ) +'h'+	
			REPLICATE('0',2-LEN(CONVERT(NVARCHAR(10),convert(int,round((e_att.TotalWorkHours%1)*60,0)))) )
			+CONVERT(NVARCHAR(10),convert(int,round((e_att.TotalWorkHours%1)*60,0)))
			TotalWorkHours,
		case 
				when c.isHoliday=1 then @HolidayLeaveTypeCode
				when isLeaveDay=1 then lv.code + CASE  WHEN lv2.LeaveTypeId IS NOT NULL THEN '/' + lv2.code WHEN c.LeaveDay = 1 THEN '' WHEN c.LeaveDay = 0.5 THEN '½' ELSE '' END
				when isOffday=1 then 'OFF'
				WHEN esum.islocal =1 AND hld.HolidayName IS NOT NULL THEN @HolidayLeaveTypeCode
				when s.code IS NOT NULL then s.code
				
			end as Code,
		isLeaveDay,
		isOffday,
		case when e_att.AttendanceDate < getdate()-1 and e_att.ShiftId IS NOT NULL AND (InFixed is null or	OutFixed is null) and not (InFixed is null and	OutFixed is null) and e_att.TotalWorkHours is null then 1 else 0 end isMissIO,
		case when e_att.AttendanceDate < getdate()-1 
			AND ( (e_att.ShiftId IS NOT NULL AND e_s.IsDefaultSchedule = 0)
				OR	(e_att.ShiftId IS NOT NULL AND e_s.IsLocal= 1 and e_s.IsDefaultSchedule = 1 and NOT(c.IsHoliday =1 or c.IsOffDay=1)) 
				)
			AND (InFixed is null and	OutFixed is null) and e_att.TotalWorkHours is null then 1 else 0 end isAbsent,
		CASE WHEN c.IsHoliday IS NOT NULL THEN c.IsHoliday			
			WHEN esum.islocal =1 AND hld.HolidayName IS NOT NULL THEN 1 ELSE 0 END IsHoliday,
		lk.Name	[Positions]
INTO #Calendar
FROM employee e WITH(NOLOCK) 
	LEFT JOIN #CalendarDF DF on DF.[Enabled]= e.[Enabled] AND DF.IsDeleted= e.IsDeleted
	LEFT JOIN dbo.EmployeeCalendar c WITH(NOLOCK)	on DF.WorkDate=c.WorkDate AND e.EmpId = c.EmpId  AND c.IsPublic = 1
	LEFT JOIN dbo.EmployeeAttendance e_att WITH(NOLOCK)	on DF.WorkDate=e_att.AttendanceDate AND e.EmpId = e_att.EmpId
	LEFT JOIN dbo.LeaveType lv		WITH(NOLOCK)	on lv.LeaveTypeId=c.LeaveTypeId
	LEFT JOIN dbo.LeaveType lv2		WITH(NOLOCK)	ON lv2.LeaveTypeId=c.LeaveTypeId2
	LEFT JOIN dbo.Shift s			WITH(NOLOCK)	on s.shiftid= c.shiftid
	LEFT JOIN dbo.EmployeeSummary esum WITH (NOLOCK)  		ON esum.EmpId = e.EmpId AND esum.islocal = 1  
	LEFT JOIN dbo.Holiday hld WITH (NOLOCK)  			ON (hld.FromDate BETWEEN @fromDate AND @toDate			OR hld.ToDate BETWEEN @fromDate AND @toDate)			AND (DF.WorkDate BETWEEN hld.FromDate AND hld.ToDate )
	LEFT JOIN dbo.LookupData lk  WITH(NOLOCK) ON e.JobTitleId=lk.Id and lk.LookupId = 1
	LEFT JOIN dbo.[Group] g WITH(NOLOCK) on g.groupid=e.groupid
	LEFT JOIN dbo.EmployeeSummary e_s WITH (NOLOCK) ON e_s.EmpId = e.EmpId  
WHERE DF.WorkDate between @fromDate and @toDate
	and (@empId is null or e.empid=@empId)
	and (@isLocal is null or e_s.IsLocal = @isLocal)
	and e.GroupId IN (SELECT GroupId FROM #GroupsList )
	 
SELECT a.empid,
		 SUM(CASE WHEN ISNULL(LeaveDay,0)=0 THEN 1 ELSE ISNULL(LeaveDay,0) END) TotalWorkDays
INTO #Calendar_TotalWorkDays
FROM dbo.EmployeeAttendance a WITH (NOLOCK) 
	LEFT JOIN employee e WITH(NOLOCK)  on a.empid=e.empid
	LEFT JOIN dbo.EmployeeSummary e_s WITH (NOLOCK) ON e_s.EmpId = e.EmpId  
WHERE a.attendancedate between @fromDate and @toDate
	and (@empId is null or a.empid=@empId)
	and (@isLocal is null or e_s.IsLocal = @isLocal)
	and e.GroupId IN (SELECT GroupId FROM #GroupsList )
	and  isnull(a.Absence,0)=0	 
GROUP BY a.empid

Declare @query nvarchar(4000)
set @query = '
	INSERT INTO #tmpCalendar ('+@cols+')
	SELECT '+ @cols 
	+' FROM (
		SELECT Team,Positions,EmpId,EmpCode,nickname,fullname,d,
		CASE WHEN isLeaveDay =1 THEN Code 
			WHEN isMissIO =1 AND ISNULL(TotalWorkHours,''0.00'') = ''0.00'' THEN ''?'' 
			WHEN isAbsent =1 AND ISNULL(TotalWorkHours,''0.00'') = ''0.00'' THEN ''Absent''			
			WHEN isOffday =1 AND ISNULL(TotalWorkHours,''0.00'') = ''0.00'' THEN ''OFF'' 
			WHEN IsHoliday =1 AND ISNULL(TotalWorkHours,''0.00'') = ''0.00'' THEN ''PH'' 
			
			ELSE REPLACE(TotalWorkHours,''.'',''h'')
			END Code
		FROM #Calendar	WITH(NOLOCK)
	) ea
	PIVOT
	(
		MAX(Code) FOR d IN (' + @days + ')' + 
	') AS pvt'


IF @isDebug = 1 print @query
EXECUTE sp_executesql @query

SELECT @query='INSERT  INTO #tmpCalendar (Team,' + @days + ')' + CHAR(13)
SELECT @query=@query + 'VALUES( '''','
	
SELECT @totalDays = DAY(@ToDate),@i = 1

while (@i<=@totalDays)
begin
	SET @query = @query + '''' + convert (nvarchar(20),convert(datetime,@fromDate),106) + ' (' + LEFT (DATENAME(weekday, @fromDate),3) + ')'',' + CHAR(13)
	SET @fromDate=CONVERT(VARCHAR(10),CONVERT(DATETIME,@fromDate)+1,111)+ ' 00:00:00'
	set @i=@i+1	
end 

SELECT @query=LEFT(@query,LEN(@query)-2) + ')'

IF @isDebug = 1 print @query
EXECUTE sp_executesql @query 

SELECT @query='SELECT EmpCode AS [Staff ID],
			Team AS Section,
			fullname AS [Full Name/Nick],
			nickname AS [Nick],
			ISNULL(TotalWorkDays,0) AS [Count WorkDay],
	' + @days

 
SELECT @query= @query +' FROM #tmpCalendar cl WITH(NOLOCK)
	LEFT JOIN #Calendar_TotalWorkDays ttd WITH(NOLOCK)
		ON cl.EmpId = ttd.EmpId
Order by Team,[Positions],fullname
'

IF @isDebug = 1 print @query
EXECUTE sp_executesql @query 

DROP TABLE #Calendar_TotalWorkDays
DROP TABLE #tmpCalendar

DROP TABLE #Calendar
DROP TABLE #GroupsList
DROP TABLE #CalendarDF