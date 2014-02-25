 
GO
/****** Object:  StoredProcedure [dbo].[DBA_Job_EmployeeCalendar_Insert_weekly]    Script Date: 1/22/2014 2:51:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
ALTER PROCEDURE [dbo].[EmployeeCalendar_Update_byDefaultShift]
	@empid int,
	@ErrCode int=0 OUTPUT,
	@ErrMsg varchar(200)='' OUTPUT
AS
/*
Created: Tom.Vo@2013-10-23
Task: Update Shift of Employee Calendar
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:

*/
SET NOCOUNT ON

DECLARE	
	@fromdate datetime, 
	@todate datetime	

SELECT @fromdate = GETDATE()

set @fromdate = convert(varchar(10),@fromdate,111)

UPDATE ec 
SET 
	ec.ShiftID = case when datepart(dw, ec.WorkDate)=1 then SunShift
				when datepart(dw, ec.WorkDate)=2 then MonShift
				when datepart(dw, ec.WorkDate)=3 then TueShift
				when datepart(dw, ec.WorkDate)=4 then WedShift
				when datepart(dw, ec.WorkDate)=5 then ThuShift
				when datepart(dw, ec.WorkDate)=6 then FriShift
				when datepart(dw, ec.WorkDate)=7 then SatShift
			end ,
	ec.isOffDay =	case when es.IsLocal =1 AND hld.Id IS NOT NULL then 0 
				when datepart(dw, ec.WorkDate)=1 and SunShift is null then 1 
				when datepart(dw, ec.WorkDate)=2 and MonShift is null then 1
				when datepart(dw, ec.WorkDate)=3 and TueShift is null then 1
				when datepart(dw, ec.WorkDate)=4 and WedShift is null then 1
				when datepart(dw, ec.WorkDate)=5 and ThuShift is null then 1
				when datepart(dw, ec.WorkDate)=6 and FriShift is null then 1
				when datepart(dw, ec.WorkDate)=7 and SatShift is null then 1
				else 0
			end ,
	ec.isHoliday	=	case when es.IsLocal =1 AND  hld.Id IS NOT NULL then 1 else 0 end 
 FROM EmployeeCalendar ec 
LEFT JOIN dbo.EmployeeDefaultShift s WITH(NOLOCK) 	ON ec.EmpId = s.EmpID 
inner join  EmployeeSummary es WITH(NOLOCK) on ec.EmpId = es.EmpId
inner join Employee ee WITH(NOLOCK) on ee.EmpId = es.EmpId
LEFT JOIN dbo.Holiday hld WITH(NOLOCK)  ON WorkDate between hld.FromDate and hld.ToDate

where es.IsLocal = 1
	and es.IsDefaultSchedule = 1
	and isnull(IsDeleted,0)=0 
	and(ec.empid=@empid)
	and ec.WorkDate >=@fromdate

 IF @@ERROR <> 0 
	SELECT @ErrCode=100,@ErrMsg=N'Create Default Calendar for employee failed'
ELSE 
	SELECT @ErrCode=0,@ErrMsg=''


