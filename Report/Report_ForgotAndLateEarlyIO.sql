USE [HRM_SMS]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Report_ForgotAndLateEarlyIO] 
	@empId INT = NULL
	,@fromDate DATETIME
	,@toDate DATETIME
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

DECLARE @date DATETIME

--SET @date = getdate()
--SET @date = CONVERT(VARCHAR(10), @date, 111)
--SET @fromDate = dateadd(d, - 10, @date)
--SET @toDate = dateadd(d, + 10, @date)

IF OBJECT_ID('tempdb..#tmpRequest') IS NOT NULL
	DROP TABLE #tmpRequest

CREATE TABLE #tmpRequest (
	attendancedate DATETIME
	,ShiftId INT
	,EmpID INT
	,LateIn BIT
	,EarlyOut BIT
	,RequestType INT
	,RequestId_miss INT
	,RequestId_io INT
	,InFixed DATETIME
	,OutFixed DATETIME
	)

INSERT INTO #tmpRequest
SELECT attendancedate
	,a.ShiftId
	,a.EmpId
	,a.LateIn
	,a.EarlyOut
	,r.RequestType
	,iom.RequestId
	,ior.RequestId
	,InFixed
	,OutFixed
FROM dbo.EmployeeAttendance a WITH (NOLOCK)
LEFT JOIN dbo.WorkingTimeRequest r WITH (NOLOCK) ON a.EmpId = r.EmpId
	AND r.CurrentStatus IN (
		1
		,2
		,3
		)
LEFT JOIN dbo.InoutMissRequest iom WITH (NOLOCK) ON iom.RequestId = r.RequestId
	AND iom.OnDate = attendancedate
LEFT JOIN dbo.InoutRequest ior WITH (NOLOCK) ON ior.RequestId = r.RequestId
	AND ior.FromDate = attendancedate
WHERE a.attendancedate BETWEEN @fromDate
		AND @todate
	AND (@empId IS NULL OR a.empid = @empId)
	--AND isnull(Absence, 0) = 0
	AND a.ShiftId IS NOT NULL

DELETE tmp
FROM #tmpRequest tmp
INNER JOIN #tmpRequest A ON A.attendancedate = tmp.attendancedate
	AND A.EmpID = tmp.EmpID
WHERE (
		A.InFixed IS NULL
		AND A.RequestType = 1
		)
	OR (
		A.OutFixed IS NULL
		AND A.RequestType = 2
		)
	OR (
		A.LateIn = 1
		AND A.RequestType = 3
		)
	OR (
		A.EarlyOut = 1
		AND A.RequestType = 4
		)

DELETE #tmpRequest
WHERE isnull(LateIn, 0) <= 0
	AND isnull(EarlyOut, 0) <= 0
	AND InFixed IS NOT NULL
	AND OutFixed IS NOT NULL

SELECT tblA.EmpId
	,ee.Code
	,ee.ChineseName
	,ee.NickName
	,ee.FullName
	,ee.Email
	,attendancedate
	,sh.ShiftID
	,sh.Code
	,max(CASE 
			WHEN isnull(LateIn, 0) > 0
				THEN 1
			ELSE 0
			END) isLateIn
	,max(CASE 
			WHEN isnull(EarlyOut, 0) > 0
				THEN 1
			ELSE 0
			END) isEarlyOut
	,max(CASE 
			WHEN InFixed IS NULL
				THEN 1
			ELSE 0
			END) isMissingCheckIn
	,max(CASE 
			WHEN OutFixed IS NULL
				AND AttendanceDate < @todate
				THEN 1
			ELSE 0
			END) isMissingCheckOut
FROM 
--	(
--	SELECT DISTINCT EmpId
--		,ShiftId
--		,attendancedate
--		,LateIn
--		,EarlyOut
--		,InFixed
--		,OutFixed
--	FROM #tmpRequest tmp
--	) 
	#tmpRequest tblA
LEFT JOIN dbo.Employee ee WITH (NOLOCK) ON tbla.EmpID = ee.EmpId
LEFT JOIN dbo.Shift sh WITH (NOLOCK) ON tbla.ShiftId = sh.ShiftID
GROUP BY tblA.EmpId
	,ee.Code
	,ee.ChineseName
	,ee.NickName
	,ee.FullName
	,ee.Email
	,attendancedate
	,sh.ShiftID
	,sh.Code
ORDER BY 1

DROP TABLE #tmpRequest
