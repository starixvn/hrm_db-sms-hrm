USE HRM_SMS
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Overtime_GetRequestByRequestID] 
	@RequestID bigint
AS
/*
Created: Tom.Vo@2013-11-05
Task:Get Request By RequestID
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT 
				r.RequestId,
				r.empID,
				8 RequestType,
				r.Month AS RequestDate,		
				r.CreatedDate,
				r.currentstatus Status,	
				e.EmpId AS RequesterID,
				e.NickName AS Requester,
				e.FullName AS FullNameRequester,
				g.Name AS Team,
				g.Code AS TeamCode,

				ap_V.EmpId AS VerifierID,
				ap_V.NickName as VerifierBy,
				ap_V.FullName as FullNameVerifierBy,
				r.VerifiedDate,
				r.VerifiedStatus,

				ap_A.EmpId AS ApproverID,
				ap_A.NickName as ApproverBy,
				ap_A.FullName as FullNameApproverBy,
				r.ApprovedDate,
				r.ApprovedStatus,

				ap_H.EmpId AS HRID,
				ap_H.NickName as HRBy,
				ap_H.FullName as FullNameHRBy,
				r.HRDate,
				r.HRStatus,
				
				r.[NormalHours],
			    r.[OffHours],
			    r.[PublicHours],
				(r.[NormalHours]+r.[OffHours]+r.[PublicHours]) ToTalHours,
				NULL Remark,
				

				r.ModifiedBy ModifiedByID,
				e_m.NickName as ModifiedBy,
				e_m.FullName as FullNameModified,
				r.ModifiedDate
	FROM  [dbo].[OTMonthlyRequest] r WITH (NOLOCK)
				LEFT JOIN [dbo].Employee ap_V WITH (NOLOCK) ON ap_V.empid = r.VerifierId
				LEFT JOIN [dbo].Employee ap_A WITH (NOLOCK) ON ap_A.empid = r.ApproverId
				LEFT JOIN [dbo].Employee ap_H WITH (NOLOCK) ON ap_H.empid = r.HRId
				LEFT JOIN Employee e_m WITH (NOLOCK) ON e_m.empID = r.ModifiedBy

				LEFT JOIN Employee e WITH (NOLOCK) ON e.empID = r.empID	
				
				LEFT JOIN [Group] g WITH (NOLOCK) ON e.GroupID = g.GroupID

	WHERE r.RequestId = @RequestID
END
