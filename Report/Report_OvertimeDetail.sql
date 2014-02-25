--USE [HRM_SMS]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].Report_OvertimeDetail
	@fromDate datetime, 
	@toDate datetime, 
	
	@EmpID INT=NULL,
	@JobTitleId varchar(1000) = '',
	@groupIds varchar(max) = '',
	
	@isLocal bit = NULL,

	@isDebug BIT=0
AS
/*
Created: Tom.Vo@2013-10-23
Task: Get Overtime Detail Report 
DB: HRM_SMS
Original: 

Revisions:  
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @sWhere NVARCHAR(1000)='',@bWhere BIT=0

	SELECT @fromDate = CONVERT(VARCHAR(50),@fromDate,111)
	SELECT @toDate = CONVERT(VARCHAR(50),@toDate,111)

	CREATE TABLE #GroupsList (GroupId TINYINT)

	IF ISNULL(@groupids,'') <>''
		BEGIN
			INSERT INTO #GroupsList (GroupId)
				SELECT g.val 
				FROM fnc_strSplit (@groupids, ',') AS g
		END

	CREATE TABLE #JobTitleList (JobTitleId TINYINT)

	IF ISNULL(@JobTitleId,'')  <>''
		BEGIN 
			INSERT INTO #JobTitleList (JobTitleId)
			SELECT val FROM fnc_strSplit (@JobTitleId, ',')

			SELECT @sWhere = @sWhere + CASE WHEN @bWhere = 1 THEN ' AND ' ELSE ' WHERE ' END 
				+ ' ( e.JobTitleId IN (SELECT JobTitleId FROM #JobTitleList ) )' + CHAR(13) 
					, @bWhere = 1
		END

	SELECT ot.OvertimeDate [OvertimeDate]
		,ot.[EmpId] AS [EmpId]
		,ee.NickName
		,ee.FullName
		,gg.GroupId TeamID
		,gg.Code Team
		,gg.Name TeamName
		,ee.JobTitleId [PositionID]
		,lk.Name	[Positions]
		,s.ShiftId [ShiftId]
		,s.Code [Schedule]
		,CONVERT(VARCHAR(5),ot.TimeIn,108) TimeIn
		,CONVERT(VARCHAR(5),ot.[TimeOut],108) [TimeOut]
		,ot.TotalHours TotalWorkHours
		,ot.NormalHours
		,ot.[OffHours]
		,ot.[PublicHours]
		,ot.[Remark]
		,ot.[Status]
	FROM [dbo].[OTDailyRequest] ot WITH (NOLOCK)
		INNER JOIN dbo.[Shift] s WITH (NOLOCK) ON s.ShiftId = ot.[Schedule]
		INNER JOIN dbo.Employee ee WITH(NOLOCK) ON ee.EmpId = ot.EmpId		
		INNER JOIN dbo.[Group] gg WITH(NOLOCK) ON ee.GroupId = gg.GroupId
		LEFT JOIN dbo.EmployeeSummary e_s WITH (NOLOCK) ON e_s.EmpId = ee.EmpId  
		LEFT JOIN dbo.LookupData lk		WITH(NOLOCK) 	ON ee.JobTitleId=lk.Id and LookupId = 1
	WHERE ot.OvertimeDate BETWEEN @fromDate AND @toDate
		AND (@EmpID IS NULL OR ot.EmpId = @EmpID)
		AND (@isLocal is null or e_s.IsLocal = @isLocal)
		AND (ISNULL(@groupids,'')='' OR ee.GroupId IN (SELECT GroupId FROM  #GroupsList))
		AND (ISNULL(@JobTitleId,'')='' OR ee.JobTitleId IN (SELECT JobTitleId FROM #JobTitleList ) )
	ORDER BY gg.Code , ee.NickName , ot.OvertimeDate

	DROP TABLE #GroupsList
	DROP TABLE #JobTitleList

END
