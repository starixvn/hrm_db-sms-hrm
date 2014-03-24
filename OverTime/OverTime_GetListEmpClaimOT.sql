
ALTER PROCEDURE [dbo].OverTime_GetListEmpClaimOT

AS
/*
Created: Tom.Vo@2013-11-04
Task:Get List Emp Claim OT
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
*/

SET NOCOUNT ON;


SELECT ee.EmpId EmployeeId, ee.NickName,ee.FullName , ee.Email,ee.Roles 
FROM dbo.Employee ee WITH(NOLOCK)
INNER JOIN dbo.EmployeeSummary es WITH(NOLOCK)
	 ON ee.EmpId = es.EmpId
WHERE (ee.isDeleted IS NULL OR ee.isDeleted = 0)
		AND (es.CanOT = 1)  
		AND ISNULL(ee.ResignedDate,GETDATE()+30)>GETDATE()
UNION 
SELECT ee.EmpId EmployeeId, ee.NickName,ee.FullName , ee.Email,ee.Roles 
FROM dbo.Employee ee WITH(NOLOCK)
INNER JOIN dbo.[EmployeeSupervisor]  su WITH(NOLOCK)
	ON ee.EmpId = su.OwnerId AND su.RequestType = 8 AND su.ActionType IN (2,3)
WHERE (ee.isDeleted IS NULL OR ee.isDeleted = 0)
		AND ISNULL(ee.ResignedDate,GETDATE()+30)>GETDATE()
		AND (ee.Roles like '%2%' OR ee.Roles like '%3%' )