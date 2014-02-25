
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

SELECT ee.EmpId EmployeeId, ee.NickName,ee.FullName , ee.Email 
FROM dbo.Employee ee WITH(NOLOCK)
INNER JOIN dbo.EmployeeSummary es WITH(NOLOCK)
	 ON ee.EmpId = es.EmpId
WHERE (ee.isDeleted IS NULL OR ee.isDeleted = 0)
		AND es.CanOT = 1
