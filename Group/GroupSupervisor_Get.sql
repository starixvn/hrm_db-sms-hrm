USE [HRM_SMS]
GO
/****** Object:  StoredProcedure [dbo].[EmployeeSupervisor_Get]    Script Date: 7/23/2014 8:57:59 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[GroupSupervisor_Get]
	@GroupIds VARCHAR(MAX) = ''
AS
/*
Created: 20140723@Quinn.Vo
Task: Get list supervisors by group ids.
DB: NexEPA
Original: 

Revisions:  
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @Supervisors TABLE (
		GroupId INT,
		ActionType TINYINT,
		Supervisors NVARCHAR(1000)
	)

	DECLARE @SupervisorActions TABLE (
		GroupId INT,
		ActionType TINYINT
	)

	DECLARE @Groups TABLE (GroupId INT)
	IF ISNULL(@GroupIds, '') <> ''
	BEGIN
		INSERT INTO @Groups (GroupId)
		SELECT val FROM fnc_strSplit (@GroupIds, ',')
	END

	INSERT INTO @SupervisorActions(GroupId, ActionType) SELECT GroupId, 2 FROM @Groups
	INSERT INTO @SupervisorActions(GroupId, ActionType) SELECT GroupId, 3 FROM @Groups
	INSERT INTO @SupervisorActions(GroupId, ActionType) SELECT GroupId, 4 FROM @Groups
	INSERT INTO @SupervisorActions(GroupId, ActionType) SELECT GroupId, 5 FROM @Groups

	INSERT INTO @Supervisors(GroupId, ActionType, Supervisors)
	SELECT es.GroupId, es.ActionType, 
	STUFF((
				SELECT CAST(', ' AS VARCHAR(MAX)) + a.NickName
				FROM (
					SELECT DISTINCT su.GroupId, ActionType, e.NickName
					FROM [dbo].GroupSupervisor AS su WITH(NOLOCK)
						INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON su.OwnerId = e.EmpId
					WHERE (ISNULL(@GroupIds, '') = '' OR su.GroupId IN (SELECT GroupId FROM @Groups))
						AND su.ActionType IN (2, 3, 4, 5)
						
				) AS a
				WHERE a.GroupId = es.GroupId AND a.ActionType = es.ActionType
				FOR XML PATH('')
				), 1, 1, '') AS Supervisor
	FROM @SupervisorActions AS es
	ORDER BY es.GroupId, es.ActionType

	SELECT g.GroupId, g.Code, g.Name, sp.ActionType, sp.Supervisors
	FROM @Supervisors AS sp
	INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON sp.GroupId = g.GroupId
	ORDER BY sp.GroupId, sp.ActionType
END
