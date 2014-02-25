USE HRM_SMS
GO
/****** Object:  StoredProcedure [dbo].[WorkingTimeRequest_ApproveRequest_7]    Script Date: 2013-11-07 9:55:07 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--DROP PROCEDURE [dbo].OverTimeRequest_ApproveDailySingleRequest

ALTER PROCEDURE [dbo].OverTime_GetDetailByListRequestID
	@ListRequestID varchar(8000)='' 
AS
/*
Created: Tom.Vo@2013-11-13
Task: approve Overtime request form (type 8)
DB: HRM_SMS
Original: 

Revisions:
Param's Explanation:
*/
SET NOCOUNT ON;

IF OBJECT_ID('tempdb..#RequestID') IS NOT NULL
		DROP TABLE #RequestID

CREATE TABLE #RequestID (RequestID INT)

IF ISNULL(@ListRequestID,'') <>''
	INSERT INTO #RequestID  (RequestID)
	SELECT val FROM fnc_strSplit (@ListRequestID, ',')
	
	SELECT ot.OvertimeDate [OvertimeDate]
		,ot.RequestId
		,ot.[EmpId] AS [EmpId]
		,ee.NickName
		,ee.FullName
		,s.ShiftId [ShiftId]
		,s.Code [ShiftName]
		,s.TotalHours [ShiftTotalHours]
		,CONVERT(VARCHAR(5),ot.TimeIn,108) TimeIn
		,CONVERT(VARCHAR(5),ot.[TimeOut],108) [TimeOut]
		,ot.TotalHours
		,ot.NormalHours
		,ot.[OffHours]
		,ot.[PublicHours]
		,ot.[Remark]
		,ot.[Status]
		,ec.IsHoliday
		,ec.IsOffDay
		,ec.IsKeepInView
	FROM [dbo].[OTDailyRequest] ot WITH (NOLOCK)
		INNER JOIN dbo.[Shift] s WITH (NOLOCK) ON s.ShiftId = ot.[Schedule]
		INNER JOIN dbo.Employee ee WITH(NOLOCK) ON ee.EmpId = ot.EmpId
		INNER JOIN dbo.EmployeeCalendar ec WITH(NOLOCK) ON ec.WorkDate = ot.OvertimeDate AND ec.EmpId = ot.EmpId
	WHERE ot.RequestID IN (SELECT RequestID FROM #RequestID ) 
	ORDER BY ee.NickName , ot.OvertimeDate

	DROP TABLE #RequestID