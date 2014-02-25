USE HRM_SMS
GO
/****** Object:  StoredProcedure [dbo].[WorkingTimeRequest_GetRequestByDate_AllType]    Script Date: 2013-11-04 10:31:47 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].OverTime_GetRequestMonthlyByHR
	@SupervisorID INT=NULL,
	@empid int = null,
	@groupids varchar(max) = '',
	@fromdate datetime,
	@todate datetime,
	@status varchar(max) = null,
	@excludedEmpID int= null,
	@role varchar(max) = '',

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

SELECT @fromdate = CONVERT(VARCHAR(10),@fromDate,111) + ' 00:00:00',
		@todate = CONVERT(VARCHAR(10),@toDate,111) + ' 23:59:59'

CREATE TABLE #status (Currentstatus TINYINT)

IF @role='6' AND LEN(ISNULL(@status,''))=0
BEGIN
	IF LEN(ISNULL(@status,'')) = 0
		SET @status =  '1,2,3,4,5,6,7'

	IF ISNULL(@status,'') <>''
		INSERT INTO #status  (Currentstatus)
		SELECT val FROM fnc_strSplit (@status, ',')
END

CREATE TABLE #RolesList (roleid TINYINT)
DECLARE @RoleType INT --1:Member | 2-Verifier 3-Approver 23 (Verifier+Approver) | 6-HR

IF @SupervisorID IS NOT NULL
BEGIN 
	SET @role = ISNULL(@role,'')
	IF @role <>''
		INSERT INTO #RolesList  (roleid)
		SELECT val FROM fnc_strSplit (@role, ',')
	
	SET @role = 1
	SELECT @role = Roles FROM dbo.Employee WITH(NOLOCK) WHERE EmpId = @SupervisorID

	SELECT TOP 1 @role=Roles FROM dbo.Employee ee (NOLOCK) WHERE EmpId = @SupervisorID
	
	IF EXISTS(SELECT TOP 1 1 FROM #RolesList WHERE roleid = 6)
		BEGIN 
			IF @role LIKE '%6%'
				SET @RoleType=6
			ELSE
				BEGIN
					SELECT @ErrCode=100,@ErrMsg='You don''t have permission on this funcion.'
					RETURN
				END
				--SET @RoleType=1 
		END
	ELSE IF 2=(SELECT COUNT(1) FROM #RolesList WHERE roleid in (2,3))
		BEGIN 
			IF @role LIKE '%2%' AND @role LIKE '%3%' 
				BEGIN
					SET @RoleType=23
					IF ISNULL(@status,'') =''	
						SET @status =  '1,2,3,4,5'
				END
			ELSE IF @role LIKE '%2%'
				BEGIN
					SET @RoleType=2
					IF ISNULL(@status,'') =''		
						SET @status =  '1,2,3'
				END
			ELSE IF @role LIKE '%3%'
				BEGIN
					SET @RoleType=3
					IF ISNULL(@status,'') =''	
						SET @status =  '2,4,5'
				END
			ELSE
				BEGIN
					SELECT @ErrCode=101,@ErrMsg='You don''t have permission on this funcion.'
					RETURN
				END
				--SET @RoleType=1
		END
	ELSE IF EXISTS(SELECT TOP 1 1 FROM #RolesList WHERE roleid in (2) )
		BEGIN
			 IF @role LIKE '%2%'
				BEGIN
					SET @RoleType=2
					IF ISNULL(@status,'') =''		
						SET @status =  '1,2,3'
				END
			ELSE
				BEGIN
					SELECT @ErrCode=102,@ErrMsg='You don''t have permission on this funcion.'
					RETURN
				END
				--SET @RoleType=1 
		END
	ELSE IF EXISTS(SELECT TOP 1 1 FROM #RolesList WHERE roleid in (3) )
		BEGIN 
			IF @role LIKE '%3%'
				BEGIN
					SET @RoleType=3
					IF ISNULL(@status,'') =''		
						SET @status =  '2,4,5'
				END
			ELSE
				BEGIN
					SELECT @ErrCode=103,@ErrMsg='You don''t have permission on this funcion.'
					RETURN
				END
				--SET @RoleType=1 
		END
	ELSE
		SET @RoleType=1
END
ELSE 
	BEGIN
		SET @RoleType=1
	END
print @status
IF ISNULL(@status,'') <>''
	INSERT INTO #status  (Currentstatus)
	SELECT val FROM fnc_strSplit (@status, ',')

IF (EXISTS(SELECT TOP 1 1 FROM #status WHERE Currentstatus = 1)
	AND EXISTS(SELECT TOP 1 1 FROM #RolesList WHERE roleid = 3))
	BEGIN
		DELETE #status WHERE Currentstatus IN (2,3)
		INSERT #status (Currentstatus)
			VALUES (2),
					(3)
	END

CREATE TABLE #GroupsList (GroupId TINYINT)
SET @groupids = ISNULL(@groupids,'')

IF @groupids <>''
	INSERT INTO #GroupsList (GroupId)
	SELECT val FROM fnc_strSplit (@groupids, ',')
ELSE
	BEGIN
		INSERT INTO #GroupsList (GroupId)
		SELECT GRoupID FROM [Group] g WITH (NOLOCK)
	END


DECLARE @SQL VARCHAR(8000)
SET @SQL = 'SELECT 
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
				r.ModifiedDate,
				CONVERT(BIT,CASE WHEN OTD.RequestId IS NOT NULL THEN 1 ELSE 0 END) IsShowWarning
 FROM  [dbo].[OTMonthlyRequest] r WITH (NOLOCK)
				LEFT JOIN [dbo].Employee ap_V WITH (NOLOCK) ON ap_V.empid = r.VerifierId
				LEFT JOIN [dbo].Employee ap_A WITH (NOLOCK) ON ap_A.empid = r.ApproverId
				LEFT JOIN [dbo].Employee ap_H WITH (NOLOCK) ON ap_H.empid = r.HRId
				LEFT JOIN Employee e_m WITH (NOLOCK) ON e_m.empID = r.ModifiedBy

				LEFT JOIN Employee e WITH (NOLOCK) ON e.empID = r.empID	
				
				LEFT JOIN [Group] g WITH (NOLOCK) ON e.GroupID = g.GroupID
				LEFT JOIN (
					SELECT DISTINCT ot.RequestId 
					FROM dbo.OTDailyRequest ot WITH (NOLOCK)
						LEFT JOIN dbo.Shift s WITH (NOLOCK)
							ON ot.Schedule = s.ShiftID
						LEFT JOIN dbo.EmployeeAttendance at WITH (NOLOCK)
							ON at.AttendanceDate = ot.OvertimeDate AND at.EmpId = ot.EmpId
					WHERE ot.TotalHours- ISNULL(at.LateIn,0)/60 >= s.TotalHours+1
					) OTD
					ON OTD.RequestId = r.RequestId 
		WHERE (e.isDeleted is null or e.isDeleted = 0)'+CHAR(13)
	+'   AND	r.Month >= ''' + CONVERT(NVARCHAR(20),@fromdate)+ ''' 
				and r.Month  <= ''' + CONVERT(NVARCHAR(20),@todate)+ ''''+CHAR(13)
	+ CASE WHEN @empid is null THEN '' ELSE '   and r.empid = ' + CONVERT(NVARCHAR(13),@empid)+ '  ' +CHAR(13) END
	+ CASE WHEN @excludedEmpID is null THEN '' ELSE '   and r.empid <> ' + CONVERT(NVARCHAR(13),@excludedEmpID)+ '  ' +CHAR(13) END
	+ CASE WHEN @status is null or @status ='' THEN '' ELSE '			and r.currentstatus IN (SELECT Currentstatus FROM #status ) ' +CHAR(13) END
	+ CASE WHEN @groupids ='' THEN '' ELSE '		and e.GroupId IN (SELECT GroupId FROM #GroupsList ) ' +CHAR(13) END
	+ CASE WHEN @RoleType IN (1,6) THEN ''
			WHEN @RoleType = 2 THEN ' AND r.VerifierId =' + CONVERT(NVARCHAR(13),@SupervisorID) + CHAR(13)
			WHEN @RoleType = 3 THEN ' AND r.ApproverId =' + CONVERT(NVARCHAR(13),@SupervisorID) + CHAR(13)
			WHEN @RoleType = 23 THEN ' AND (r.ApproverId =' + CONVERT(NVARCHAR(13),@SupervisorID) 
										+' OR	r.VerifierId =' + CONVERT(NVARCHAR(13),@SupervisorID) + ')'+ CHAR(13)
			END
	+'			ORDER BY r.Month DESC'
	
	IF @isDebug = 1 PRINT @SQL 
	IF @isDebug = 1 PRINT @RoleType
	EXEC (@SQL )

SELECT @ErrCode=0,@ErrMsg=''
	
DROP TABLE #GroupsList
DROP TABLE #RolesList
DROP TABLE #status
