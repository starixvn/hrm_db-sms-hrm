USE HRM_SMS
GO
/****** Object:  StoredProcedure [dbo].[WorkingTimeRequest_GetRequestByDate_AllType]    Script Date: 2013-11-04 10:31:47 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].OverTime_GetRequestMonthlyByEmpId
	@Empid int,
	@Year INT,

	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(200) = '' OUTPUT,
	@isDebug BIT=0
AS
/*
Created: Tom.Vo@2013-11-04
Task:Get Request By Date For Overtime
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
*/
SET NOCOUNT ON;

DECLARE @CanOT BIT
SELECT TOP 1 @CanOT =CanOT  from dbo.EmployeeSummary WITH(NOLOCK) WHERE EmpId = @EmpId

IF (@CanOT = 0)
BEGIN
	SELECT @ErrCode = 100,@ErrMsg = 'You don''t have permission on this function.'
	RETURN
END

DECLARE @fromdate datetime,@todate datetime,@Month datetime

IF YEAR(GETDATE())=@Year
	SELECT @Month = CONVERT(VARCHAR(10),@Year) + '/' + CONVERT(VARCHAR(10),MONTH(GETDATE())) + + '/' + CONVERT(VARCHAR(10),DAY(GETDATE())) +' 00:00:00'
ELSE 
	SELECT @Month = CONVERT(VARCHAR(10),@Year) + '/12/01 00:00:00'

SELECT @Month = CASE WHEN DAY(GETDATE()) BETWEEN 10 AND 31 THEN DATEADD(MONTH,1,@Month) ELSE @Month  END

IF YEAR(@Month)>@Year
	SELECT @Month = CONVERT(VARCHAR(10),@Year) + '/12/01 00:00:00'

SELECT @fromDate = CONVERT(VARCHAR(10),@Year) + '/01/01 00:00:00'
		,@toDate = @Month

CREATE TABLE #Calendar([Month] datetime,[Enabled] BIT,IsDeleted BIT)

WHILE (CONVERT(DATETIME,@fromDate)<=CONVERT(DATETIME,@toDate)) 
	BEGIN
		INSERT INTO #Calendar([Month],[Enabled],IsDeleted) VALUES(@fromDate,1,0)
		SET @fromDate=DATEADD(MONTH,1,@fromDate)
	END

SELECT @fromDate = CONVERT(VARCHAR(10),@Year) + '/01/01 00:00:00'

DECLARE @SQL VARCHAR(8000)
SET @SQL = 'SELECT 
				r.RequestId,
				r.empID,
				8 RequestType,
				cl.Month AS RequestDate,		
				r.CreatedDate,
				r.currentstatus Status,	
				' + CONVERT(NVARCHAR(13),@empid)+ ' AS RequesterID,
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
 FROM  #Calendar cl 
				LEFT JOIN [dbo].[OTMonthlyRequest] r WITH (NOLOCK) ON r.Month = cl.[Month]
					AND r.Month >= ''' + CONVERT(NVARCHAR(20),@fromdate)+ ''' 
					AND r.Month  <= ''' + CONVERT(NVARCHAR(20),@todate)+ ''''+CHAR(13)
+'					AND r.empid = ' + CONVERT(NVARCHAR(13),@empid)+ '  ' +CHAR(13) 
+'				LEFT JOIN [dbo].Employee ap_V WITH (NOLOCK) ON ap_V.empid = r.VerifierId
				LEFT JOIN [dbo].Employee ap_A WITH (NOLOCK) ON ap_A.empid = r.ApproverId
				LEFT JOIN [dbo].Employee ap_H WITH (NOLOCK) ON ap_H.empid = r.HRId
				LEFT JOIN Employee e_m WITH (NOLOCK) ON e_m.empID = r.ModifiedBy

				LEFT JOIN Employee e WITH (NOLOCK) ON e.empID = r.empID	
				
				LEFT JOIN [Group] g WITH (NOLOCK) ON e.GroupID = g.GroupID
				ORDER BY cl.Month DESC'
	
	IF @isDebug = 1 PRINT @SQL 
	EXEC (@SQL )

SELECT @ErrCode=0,@ErrMsg=''
	
DROP TABLE #Calendar