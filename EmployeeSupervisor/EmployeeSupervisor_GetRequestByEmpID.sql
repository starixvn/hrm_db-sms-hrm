--USE [HRM_SMS]
GO
/****** Object:  StoredProcedure [dbo].[EmployeeSupervisor_GetListSupervisorByEmpID]    Script Date: 2013-10-29 4:22:12 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[EmployeeSupervisor_GetRequestByEmpID]
	@EmpId  INT,
	@Role	TINYINT=NULL
AS
/*
Created: TOM.VO@2013/10/25
Task: Get list supervisor for Employee by EmpId.
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
*/
SET NOCOUNT ON

IF @Role IS NULL	
	SELECT  su.OwnerId , ee.FullName, ee.NickName, su.ActionType,ee.Email,--OrderNo,
		MAX(case when RequestType in (1,2) THEN 1 ELSE 0 END) CheckInOuts ,
		MAX(case when RequestType in (3,4) THEN 1 ELSE 0 END) LateInEarlyOuts ,
		MAX(case when RequestType in (5) THEN 1 ELSE 0 END) ChangeShifts ,
		MAX(case when RequestType in (6) THEN 1 ELSE 0 END) Leaves ,
		MAX(case when RequestType in (7) THEN 1 ELSE 0 END) KeepInViews,
		MAX(case when RequestType in (8) THEN 1 ELSE 0 END) Overtimes
		,isnull(g.GroupID, -1) as [TeamID], isnull(g.Name,'') as [Team]
	FROM [dbo].[EmployeeSupervisor] su WITH(NOLOCK)
	INNER JOIN [dbo].Employee ee  WITH(NOLOCK) ON su.OwnerId = ee.EmpId
	LEFT JOIN dbo.[Group] AS g WITH(NOLOCK) ON ee.GroupId = g.GroupId
	WHERE su.EmpId = @EmpId
	GROUP BY su.OwnerId , isnull(g.GroupID, -1), isnull(g.Name,'') ,ee.FullName, ee.NickName, su.ActionType,ee.Email--, OrderNo 
ELSE IF @Role =4
	SELECT  su.OwnerId , ee.FullName, ee.NickName, su.ActionType,ee.Email,--OrderNo,
		0 CheckInOuts ,
		0 LateInEarlyOuts ,
		0 ChangeShifts ,
		0 Leaves ,
		0 KeepInViews,
		0 Overtimes
		,isnull(g.GroupID, -1) as [TeamID], isnull(g.Name,'') as [Team]
	FROM [dbo].[EmployeeSupervisor] su WITH(NOLOCK)
	INNER JOIN [dbo].Employee ee  WITH(NOLOCK) ON su.OwnerId = ee.EmpId
	LEFT JOIN dbo.[Group] AS g WITH(NOLOCK) ON ee.GroupId = g.GroupId
	WHERE su.EmpId = @EmpId AND su.ActionType = @Role 
	--GROUP BY su.OwnerId , ee.FullName, ee.NickName, su.ActionType,ee.Email--,OrderNo
	ORDER BY OrderNo,su.OwnerId,su.ActionType 
ELSE

	SELECT su.OwnerId , su.FullName, su.NickName, su.ActionType,su.Email,--OrderNo,
		su.CheckInOuts ,
		su.LateInEarlyOuts ,
		su.ChangeShifts ,
		su.Leaves ,
		su.KeepInViews,
		su.Overtimes,
		su.TeamID, su.[Team] , 
		ROW_NUMBER() OVER (ORDER BY MIN(ord.OrderNo) )OrderNo
		FROM (
			SELECT  su.OwnerId , ee.FullName, ee.NickName, su.ActionType,ee.Email,--OrderNo,
				MAX(case when RequestType in (1,2) THEN 1 ELSE 0 END) CheckInOuts ,
				MAX(case when RequestType in (3,4) THEN 1 ELSE 0 END) LateInEarlyOuts ,
				MAX(case when RequestType in (5) THEN 1 ELSE 0 END) ChangeShifts ,
				MAX(case when RequestType in (6) THEN 1 ELSE 0 END) Leaves ,
				MAX(case when RequestType in (7) THEN 1 ELSE 0 END) KeepInViews,
				MAX(case when RequestType in (8) THEN 1 ELSE 0 END) Overtimes
				,isnull(g.GroupID, -1) as [TeamID], isnull(g.Name,'') as [Team]
			FROM [dbo].[EmployeeSupervisor] su WITH(NOLOCK)
			INNER JOIN [dbo].Employee ee  WITH(NOLOCK) ON su.OwnerId = ee.EmpId
			LEFT JOIN dbo.[Group] AS g WITH(NOLOCK) ON ee.GroupId = g.GroupId
			WHERE su.EmpId = @EmpId AND su.ActionType = @Role 
			GROUP BY su.OwnerId , isnull(g.GroupID, -1), isnull(g.Name,'') ,ee.FullName, ee.NickName, su.ActionType,ee.Email
		) AS Su
		LEFT JOIN [dbo].[EmployeeSupervisor] ord WITH(NOLOCK)
			ON Su.OwnerId = ord.OwnerId AND Su.ActionType = ord.ActionType AND ord.EmpId = @EmpId 
		GROUP BY su.OwnerId , su.FullName, su.NickName, su.ActionType,su.Email,--OrderNo,
		su.CheckInOuts ,
		su.LateInEarlyOuts ,
		su.ChangeShifts ,
		su.Leaves ,
		su.KeepInViews,
		su.Overtimes,
		su.TeamID, su.[Team]
		ORDER BY OrderNo

/*
	SELECT  su.OwnerId , ee.FullName, ee.NickName, su.ActionType,ee.Email,--OrderNo,
		MAX(case when RequestType in (1,2) THEN 1 ELSE 0 END) CheckInOuts ,
		MAX(case when RequestType in (3,4) THEN 1 ELSE 0 END) LateInEarlyOuts ,
		MAX(case when RequestType in (5) THEN 1 ELSE 0 END) ChangeShifts ,
		MAX(case when RequestType in (6) THEN 1 ELSE 0 END) Leaves ,
		MAX(case when RequestType in (7) THEN 1 ELSE 0 END) KeepInViews,
		MAX(case when RequestType in (8) THEN 1 ELSE 0 END) Overtimes
		,isnull(g.GroupID, -1) as [TeamID], isnull(g.Name,'') as [Team]
	FROM [dbo].[EmployeeSupervisor] su WITH(NOLOCK)
	INNER JOIN [dbo].Employee ee  WITH(NOLOCK) ON su.OwnerId = ee.EmpId
	LEFT JOIN dbo.[Group] AS g WITH(NOLOCK) ON ee.GroupId = g.GroupId
	WHERE su.EmpId = @EmpId AND su.ActionType = @Role 
	GROUP BY su.OwnerId , isnull(g.GroupID, -1), isnull(g.Name,'') ,ee.FullName, ee.NickName, su.ActionType,ee.Email--, OrderNo 
	--ORDER BY su.OwnerId,su.ActionType--,OrderNo DESC

*/