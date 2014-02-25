--USE [HRM_SMS]
GO
/****** Object:  StoredProcedure [dbo].[Employee_GetEmployeeByCode]    Script Date: 2013-10-29 4:19:18 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Employee_Export_InformationFull]

AS
/*
Created: Tom.Vo@2014-01-06
Task: Employee Information (All Data)
DB: NexHR
Original: 

Revisions:    
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT
		e.EmpID As [Employee ID]
		,e.DomainUsername AS [Domain Username]
		,e.FullName AS [Full Name]
		,e.NickName AS [Nick Name]
		,g.Name AS [Department/Team]
		,e.DOB
		,e.PlaceOfbirth AS [Place of birth]
		,e.Ethnic
		,e.Native
		,e.Religion
		,CASE WHEN e.Gender IS NULL THEN 'UnKnown'
			WHEN e.Gender =0 THEN 'Female'
			WHEN e.Gender =1 THEN 'Male'
			END as Gender 
		,CASE WHEN e.Marriage IS NULL THEN 'UnKnown'
			WHEN e.Marriage =1 THEN 'Married'
			WHEN e.Marriage =2 THEN 'Divorced'
			WHEN e.Marriage =3 THEN 'Single'
			WHEN e.Marriage =4 THEN 'Widow'
			END as Marriage
		,ISNULL(ct.Nationality,ct.CountryName) Nationality
		,e.IdCardNumber AS [ID Card No]
		,e.DateOfIDCard AS [Date of issue of ID card]
		,e.PlaceOfIDCard AS [Place of Issue of ID Card]
		,e.PassportNo AS [Passport No]
		,e.PassportExp AS [Passport Exp]
		,e.Qualification
		,e.Major
		,e.Phone AS Cellphone
		,e.HomePhone AS [Home Phone]
		,e.Email AS [Work Email]
		,e.PermanentAddress AS [Permenant Address]
		,e.CurrentAddress AS [Current Address]
		,e.Skype
		,e_s.Unit
		,lk.Name AS [Job Title]
		,e.JoinedDate AS [Group Date]
		,e_s.CompanyDate AS [Company Date]
		,e.ConfirmedDate AS [Confirmed Date]
		,e.ResignedDate AS [Resigned Date]
		,e_s.WorkingDays AS [Working days per Month]
		,e_s.WorkingHours AS [Working hours per day]
		,e_s.OffDaysbyWeek AS [Number of Offday]
		,e_s.AnnualLeaveBalance AS [Leave Balance]
		,CASE WHEN e_s.IsLocal = 1 THEN 'LOCAL' ELSE 'EXPAT' END  Category
		,e_cs.BankAccount AS [Bank Account]
		,e_cs.TaxCode AS [Tax Code]
		,e_cs.SocialInsuranceNo AS [Social Insurance No]
		,e_cs.RegisteredHospital AS [Registered Hospital]
		,e_cs.Contract1
		,e_cs.Contract2
		,e_cs.Contract3
		,e_cs.Contract4
		,e_cs.Contract5
		,e_cs.History
		,e.ResignedDate AS [Resignation Date]

	from dbo.Employee e WITH (NOLOCK) 
		LEFT JOIN dbo.EmployeeSummary e_s WITH (NOLOCK) ON e_s.EmpId = e.EmpId
		LEFT JOIN dbo.EmployeeContract e_cs WITH (NOLOCK) ON e_cs.EmpId = e.EmpId 
		LEFT JOIN dbo.[Group] g WITH (NOLOCK) ON e.GroupID = g.GroupID
		LEFT JOIN dbo.Country ct WITH (NOLOCK) ON e_s.CountryCode = ct.CountryCode
		LEFT JOIN [dbo].[Lookup] l WITH(NOLOCK) ON l.Code = 'JT'
		LEFT JOIN [dbo].[LookupData] LK WITH(NOLOCK) ON l.Id = LK.LookupId AND e.JobTitleId = lk.ID
	WHERE (e.isDeleted IS NULL OR e.isDeleted = 0) AND e.Enabled = 1
END