USE [HRM_SMS]
GO
/****** Object:  StoredProcedure [dbo].[Employee_GetByRole]    Script Date: 2013-12-12 1:15:23 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Employee_GetByRole] 
	@RoleIds varchar(20),
	@query nvarchar(256),
	@ExcludeIds varchar(2000)	
AS
/*
Created: 2013/10/22@Quinn
Task: Get list employee by role (for supervisor list)
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
*/
SET NOCOUNT ON

DECLARE @q nvarchar(258)
SET @q = '%' + @query + '%'
IF LEN(@query) = 0 OR @query = ';'
	SET @query = NULL

CREATE TABLE #EmpIdList (EmpId INT)
INSERT INTO #EmpIdList (EmpId)
SELECT val FROM fnc_strSplit (@ExcludeIds, ',')

SELECT 
	e.EmpId AS Id,
		e.Code,
		e.DomainUsername,
		e.FullName,
		e.NickName,
		e.DOB,
		e.Email,
		e.JobTitleId,
		e.Enabled,
		e.Phone,
		e.Gender,
		e.Roles,
		e.ManagerId,
		e.JoinedDate,
		e.ConfirmedDate,
		e.ResignedDate,
		e.Skype,
		e.Yahoo,
		e.Marriage,
		e.LastLogin,
		e.CreatedDate,
		e.CreatedBy,
		e.ModifiedDate,
		e.ModifiedBy,
		e.isDeleted,
		e.PermanentAddress as Address,
		e.CurrentAddress,
		e.IdCardNumber as CardNo,
		e.PassportNo,
		e.PassportExp,
		e.Password,
		e.GroupId,
		isnull(e.GroupID, -1) as [TeamID], 
		isnull(g.Name,'') as [Team]
FROM dbo.Employee AS e WITH (NOLOCK)
	LEFT JOIN dbo.[Group] AS g WITH(NOLOCK)
		ON e.GroupId = g.GroupId
WHERE e.Roles like '%' + @RoleIds + '%'
AND EmpId NOT IN (SELECT EmpId FROM #EmpIdList)
AND (E.isDeleted IS NULL OR e.isDeleted = 0)
AND e.Enabled = 1
AND (
		@query IS NULL
		OR NickName LIKE @q
		OR FullName LIKE @q
		OR DomainUsername LIKE @q
		OR e.Code LIKE @q
	)

DROP TABLE #EmpIdList