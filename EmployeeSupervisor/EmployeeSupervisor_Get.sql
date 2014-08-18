USE [HRM_SMS]
GO
/****** Object:  StoredProcedure [dbo].[Message_GetByCreator]    Script Date: 7/17/2014 8:40:15 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[EmployeeSupervisor_Get] 
	@EmployeeId INT = NULL,
	@ActionType	TINYINT = NULL,
	@GroupIds VARCHAR(MAX) = '',
	@IsLocal BIT = NULL
AS
/*
Created: 20140717@Quinn.Vo
Task: Get list supervisors.
DB: NexEPA
Original: 

Revisions:  
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	DECLARE @Groups TABLE (GroupId INT)
	DECLARE @Supervisors TABLE (
		EmployeeId INT,
		ActionType TINYINT,
		Supervisors NVARCHAR(1000)
	)

	IF(@GroupIds <> '')
	BEGIN
		INSERT INTO @Groups (GroupId)
		SELECT val FROM fnc_strSplit (@GroupIds, ',')
	END


	INSERT INTO @Supervisors(EmployeeId, ActionType, Supervisors)
	SELECT es.OwnerId AS EmployeeId, es.ActionType, 
	STUFF((
				SELECT CAST(', ' AS VARCHAR(MAX)) + a.NickName
				FROM (
					SELECT DISTINCT OwnerId, ActionType, e.NickName
					FROM [dbo].[EmployeeSupervisor] AS su WITH(NOLOCK)
						INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON su.EmpId = e.EmpId
					WHERE 
					su.ActionType IN (4, 5)
					AND (@ActionType IS NULL OR ActionType = @ActionType)
				) AS a
				WHERE a.OwnerId = es.OwnerId AND a.ActionType = es.ActionType
				FOR XML PATH('')
				), 1, 1, '') AS Supervisor
	FROM (
		SELECT OwnerId, ActionType FROM dbo.EmployeeSupervisor WITH (NOLOCK)
		WHERE 
			ActionType IN (4, 5)
			AND (@ActionType IS NULL OR ActionType = @ActionType)
		GROUP BY OwnerId, ActionType
		) AS es
	ORDER BY es.OwnerId, es.ActionType

	INSERT INTO @Supervisors(EmployeeId, ActionType, Supervisors)
	SELECT es.EmpId AS EmployeeId, es.ActionType, 
	STUFF((
				SELECT CAST(', ' AS VARCHAR(MAX)) + a.NickName
				FROM (
					SELECT DISTINCT su.EmpId, ActionType, e.NickName
					FROM [dbo].[EmployeeSupervisor] AS su WITH(NOLOCK)
						INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON su.OwnerId = e.EmpId
					WHERE
					su.ActionType IN (2, 3)
					AND (@ActionType IS NULL OR ActionType = @ActionType)
				) AS a
				WHERE a.EmpId = es.EmpId AND a.ActionType = es.ActionType
				FOR XML PATH('')
				), 1, 1, '') AS Supervisor
	FROM (
		SELECT EmpId, ActionType FROM dbo.EmployeeSupervisor WITH (NOLOCK)
		WHERE 
			ActionType IN (2, 3)
			AND (@ActionType IS NULL OR ActionType = @ActionType)
		GROUP BY EmpId, ActionType
		) AS es
	ORDER BY es.EmpId, es.ActionType

	SELECT e.EmpId, e.NickName, e.FullName, g.GroupId, g.Code, g.Name, sp.ActionType, sp.Supervisors
	FROM @Supervisors AS sp
	INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON sp.EmployeeId = e.EmpId
	INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON e.EmpId = es.EmpId
	INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON e.GroupId = g.GroupId
	WHERE (@ActionType IS NULL OR sp.ActionType = @ActionType)
		AND (@EmployeeId IS NULL OR e.EmpId = @EmployeeId)
		AND (@IsLocal IS NULL OR es.IsLocal = @IsLocal)
		AND (@GroupIds = '' OR e.GroupId IN (SELECT GroupId FROM @Groups))

	ORDER BY sp.EmployeeId, sp.ActionType

END
