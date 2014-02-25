--USE [HRM_SMS]
GO
/****** Object:  StoredProcedure [dbo].[Employee_GetEmployeeByCode]    Script Date: 2013-10-29 4:19:18 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Employee_Export_InformationBasic]

AS
/*
Created: Tom.Vo@2014-01-06
Task: Employee Information Basic
DB: NexHR
Original: 

Revisions:    
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT
		e.EmpID As [Employee ID]
		,e.FullName AS [Full Name]
		,e.NickName AS [Nick Name]
		,g.Name AS [Department/Team]
		,e.JoinedDate AS [Group Date]
		,e_s.CompanyDate AS [Company Date]
		,e.ConfirmedDate AS [Confirmed Date]
		,e.ResignedDate AS [Resigned Date]
		,e.DOB
		,CASE WHEN e.Gender IS NULL THEN 'UnKnown'
			WHEN e.Gender =0 THEN 'Female'
			WHEN e.Gender =1 THEN 'Male'
			END as Gender
		,e.Phone AS Cellphone
		,e.Email AS [Work Email]
		,e.CurrentAddress AS [Current Address]
		,e_s.Unit
		,CASE WHEN e_s.IsLocal = 1 THEN 'LOCAL' ELSE 'EXPAT' END  Category

	from dbo.Employee e WITH (NOLOCK) 
		LEFT JOIN dbo.EmployeeSummary e_s WITH (NOLOCK) ON e_s.EmpId = e.EmpId
		LEFT JOIN dbo.[Group] g WITH (NOLOCK) ON e.GroupID = g.GroupID
	WHERE (e.isDeleted IS NULL OR e.isDeleted = 0) AND e.Enabled = 1
END