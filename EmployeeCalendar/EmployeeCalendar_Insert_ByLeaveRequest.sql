--USE [HRM_SMS]
GO
/****** Object:  StoredProcedure [dbo].[Employee_Calendar_Insert]    Script Date: 2013-10-29 4:18:29 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[EmployeeCalendar_Insert_ByLeaveRequest]
	@empid int,
	@fromdate datetime, 
	@todate datetime	,

	@ErrCode int = 0 OUTPUT,
	@ErrMsg varchar(200) = '' OUTPUT	
AS	

/*
Created: Tom.Vo@2013-10-21
Task: Insert default working calendar for employee by Leave Request
DB: HRM_SMS
Original: 

Revisions:  
Param's Explanation:

*/
SET NOCOUNT ON
-- cut off time

SELECT @fromdate = CONVERT(smalldatetime,convert(nvarchar(20),@fromdate,111))
	,@todate = CONVERT(smalldatetime,convert(nvarchar(20),@todate,111))

DECLARE @tblCalendare TABLE(WorkDate SmallDateTime,IsEnabled BIT) 

while @fromdate<=@todate
begin
	INSERT INTO @tblCalendare (WorkDate,IsEnabled)
	VALUES (@fromdate,1)

	set @fromdate=dateadd(d,1,@fromdate)
end
	-- se xu ly leave request o day neu can	
insert into dbo.EmployeeCalendar (EmpID, WorkDate, ShiftID, isOffDay, IsHoliday,IsPublic)
select DISTINCT s.empid,
		tblCalendare.WorkDate,
		case when es.IsDefaultSchedule = 0 then  null
			when datepart(dw, tblCalendare.WorkDate)=1 then SunShift
			when datepart(dw, tblCalendare.WorkDate)=2 then MonShift
			when datepart(dw, tblCalendare.WorkDate)=3 then TueShift
			when datepart(dw, tblCalendare.WorkDate)=4 then WedShift
			when datepart(dw, tblCalendare.WorkDate)=5 then ThuShift
			when datepart(dw, tblCalendare.WorkDate)=6 then FriShift
			when datepart(dw, tblCalendare.WorkDate)=7 then SatShift
		end as ShiftID,
		case when (es.IsLocal =1 OR (es.IsLocal =0 and es.IsExpatUseHoliday =1 )) AND hld.Id IS NOT NULL then 0 
			when es.IsDefaultSchedule = 0 then  0
			when es.IsLocal =1 AND datepart(dw, tblCalendare.WorkDate)=1 and SunShift is null then 1 
			when es.IsLocal =1 AND datepart(dw, tblCalendare.WorkDate)=2 and MonShift is null then 1
			when es.IsLocal =1 AND datepart(dw, tblCalendare.WorkDate)=3 and TueShift is null then 1
			when es.IsLocal =1 AND datepart(dw, tblCalendare.WorkDate)=4 and WedShift is null then 1
			when es.IsLocal =1 AND datepart(dw, tblCalendare.WorkDate)=5 and ThuShift is null then 1
			when es.IsLocal =1 AND datepart(dw, tblCalendare.WorkDate)=6 and FriShift is null then 1
			when es.IsLocal =1 AND datepart(dw, tblCalendare.WorkDate)=7 and SatShift is null then 1
			else 0
		end as isOffDay,
		case when (es.IsLocal =1 OR (es.IsLocal =0 and es.IsExpatUseHoliday =1 ))  AND  hld.Id IS NOT NULL then 1 else 0 end  as isHoliday,
		0 IsPublic
		
from dbo.EmployeeDefaultShift s WITH(NOLOCK) 
	inner join dbo.Employee e WITH(NOLOCK) on e.empid=s.empid
	inner join @tblCalendare tblCalendare on tblCalendare.IsEnabled = e.Enabled
	inner join dbo.EmployeeSummary es WITH(NOLOCK) on es.empid=s.empid 
	LEFT JOIN EmployeeCalendar c ON e.EmpId = c.EmpId AND c.WorkDate = tblCalendare.WorkDate 
	LEFT JOIN dbo.Holiday hld WITH(NOLOCK)  ON  tblCalendare.WorkDate between hld.FromDate and hld.ToDate	
where isnull(IsDeleted,0)=0 
	and(s.empid=@empid)
	and c.EmpId is null
	--and isnull(ResignedDate,'2079/01/01' )>@fromdate

 IF @@ERROR <> 0 
	SELECT @ErrCode=100,@ErrMsg=N'Create Default Calendar for employee failed'
ELSE 
	SELECT @ErrCode=0,@ErrMsg=''