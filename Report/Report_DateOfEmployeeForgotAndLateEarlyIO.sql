--USE [HRM_SMS]
GO
/****** Object:  StoredProcedure [dbo].[Report_EmployeeDashBoard]    Script Date: 2013-10-29 4:15:42 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Report_DateOfEmployeeForgotAndLateEarlyIO]
	@empid int,
	@date datetime
AS
/*
Created: Tom.Vo@2013-10-25
Task: Retrieve list attendance date forgot IO and Late/Early IO
DB: HRMS
Original: 

Revisions:    
Param's Explanation:
*/
SET NOCOUNT ON

DECLARE @fromDate datetime, @toDate datetime

SET @date = CONVERT(VARCHAR(10),@date,111)
SET @fromDate = cast(YEAR(@date) as varchar(4)) + '/' + cast(MONTH(@date) as varchar(2)) + '/01'
SET @toDate = dateadd(d,-1, dateadd(m,1,@fromDate))

CREATE TABLE #Calendar(attendancedate DATETIME,
			isLateIn BIT,isEarlyOut BIT,
			isMissingCheckin BIT,isMissingCheckOut BIT,
			RequestType INT,RequestId_miss INT,  RequestId_io INT )

INSERT INTO #Calendar(attendancedate ,
	isLateIn ,isEarlyOut,
	RequestType ,RequestId_miss,RequestId_io ,
	isMissingCheckin ,isMissingCheckOut)
SELECT attendancedate,
	a.LateIn , a.EarlyOut ,
	r.RequestType , iom.RequestId ,  ior.RequestId 
	,CASE WHEN InFixed IS NULL and a.shiftid is not null THEN 1 ELSE 0 END InFixed
	,CASE WHEN OutFixed IS NULL and a.shiftid is not null  THEN 1 ELSE 0 END OutFixed
FROM dbo.EmployeeAttendance a WITH (NOLOCK) 
	Left Join dbo.WorkingTimeRequest r WITH (NOLOCK) 
		ON a.EmpId = r.EmpId AND r.CurrentStatus IN (1,2,3)
	left join dbo.InoutMissRequest iom WITH (NOLOCK) 
		On iom.RequestId = r.RequestId
			and iom.OnDate =attendancedate
	left join dbo.InoutRequest ior WITH (NOLOCK) 
		On ior.RequestId = r.RequestId
			and ior.FromDate =attendancedate
	WHERE a.attendancedate between @fromDate and @todate
		and a.empid = @empid
		--and  isnull(Absence,0)=0 		 

DELETE    tmp
FROM #Calendar tmp
INNER JOIN #Calendar A
	ON A.attendancedate = tmp.attendancedate
WHERE (A.isLateIn = 1 AND A.RequestType = 3)
	OR (A.isEarlyOut = 1 AND A.RequestType = 4)
	OR (A.isMissingCheckin is null AND A.RequestType = 1)
	OR (A.isMissingCheckOut is null AND A.RequestType = 2)

SELECT DISTINCT attendancedate ,isLateIn ,isEarlyOut ,isMissingCheckin ,isMissingCheckOut
	
FROM #Calendar
WHERE isLateIn = 1 OR isEarlyOut = 1 OR isMissingCheckin = 1 OR isMissingCheckOut = 1

DROP TABLE #Calendar