USE [HRM_SMS]
GO
/****** Object:  StoredProcedure [dbo].[EmployeeSupervisor_Get]    Script Date: 7/23/2014 8:57:59 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[GroupSupervisor_GetByRole]
	@GroupId INT,
	@Role TINYINT
AS
/*
Created: 20140723@Quinn.Vo
Task: Get list supervisors by group and action type.
DB: NexEPA
Original: 

Revisions:  
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT e.EmpId, e.NickName, e.FullName, g.GroupId, g.Code, g.Name,
		CAST(MAX(CASE WHEN su.RequestType IN (1, 2) THEN 1 ELSE 0 END) AS BIT) AS HasCheckInOut,
		CAST(MAX(CASE WHEN su.RequestType IN (3, 4) THEN 1 ELSE 0 END) AS BIT) AS HasLateInEarlyOut,
		CAST(MAX(CASE WHEN su.RequestType = 5 THEN 1 ELSE 0 END) AS BIT) AS HasChangeShift,
		CAST(MAX(CASE WHEN su.RequestType = 6 THEN 1 ELSE 0 END) AS BIT) AS HasLeave,
		CAST(MAX(CASE WHEN su.RequestType = 7 THEN 1 ELSE 0 END) AS BIT) AS HasKeepInView,
		CAST(MAX(CASE WHEN su.RequestType = 8 THEN 1 ELSE 0 END) AS BIT) AS HasOvertime
	FROM dbo.GroupSupervisor AS su WITH (NOLOCK)
	INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON su.OwnerId = e.EmpId
	INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON e.GroupId = g.GroupId
	WHERE su.GroupId = @GroupId
		AND su.ActionType = @Role
	GROUP BY e.EmpId, e.NickName, e.FullName, g.GroupId, g.Code, g.Name
END
