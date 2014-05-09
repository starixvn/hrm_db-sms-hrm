--USE HRM_SMS
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER PROCEDURE [dbo].[WorkingTimeRequest_GetRequestByCreateDate_KeepInViewType]
	@SupervisorID INT=NULL,
	@empid int = null,
	@groupids varchar(max) = '',
	@fromdate datetime,
	@todate datetime,
	@status varchar(max) = null,
	@excludedEmpID int= null,
	@role   varchar(max) = '',
	@isLocal bit = NULL,

	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(200) = '' OUTPUT,
	@isDebug BIT=0
AS
/*
Created: Tom.Vo@2013-11-11
Task:Get Request By Date For KeepInViewType
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
*/
SET NOCOUNT ON

SELECT @excludedEmpID = null

SELECT @fromdate = CONVERT(VARCHAR(10),@fromDate,111) + ' 00:00:00',
		@todate = CONVERT(VARCHAR(10),@toDate,111) + ' 23:59:59'

CREATE TABLE #status (Currentstatus TINYINT)
IF ISNULL(@status,'') <>''
	INSERT INTO #status  (Currentstatus)
	SELECT val FROM fnc_strSplit (@status, ',')

CREATE TABLE #RolesList (roleid TINYINT)
DECLARE @RoleType INT --1:Member | 2-Verifier 3-Approver 23 (Verifier+Approver) | 6-HR

IF @SupervisorID IS NOT NULL
BEGIN 
	SET @role = ISNULL(@role,'')
	IF @role <>''
		INSERT INTO #RolesList  (roleid)
		SELECT val FROM fnc_strSplit (@role, ',')
	
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
	ELSE IF 2=(SELECT COUNT(1) FROM #RolesList WHERE roleid in (2,3) )
		BEGIN 
			IF @role LIKE '%2%' AND @role LIKE '%3%' 
				SET @RoleType=23
			ELSE IF @role LIKE '%2%'
				SET @RoleType=2
			ELSE IF @role LIKE '%3%'
				SET @RoleType=3
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
				SET @RoleType=2
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
				SET @RoleType=3
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

DECLARE @sGroupID VARCHAR(10)
IF @RoleType IN ('2','3','23')
	BEGIN
		SELECT TOP 1 @sGroupID= GroupId FROM dbo.Employee WITH(NOLOCK) WHERE EmpId = @SupervisorID
	END

IF (EXISTS(SELECT TOP 1 1 FROM #status WHERE Currentstatus = 1)
	AND EXISTS(SELECT TOP 1 1 FROM #RolesList WHERE roleid = 3))
	BEGIN
		DELETE #status WHERE Currentstatus IN (2)
		INSERT #status (Currentstatus)
			VALUES (2)
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

CREATE TABLE #TotalDaysRequestInMonth(empid INT,TotalDaysRequest INT)

SET @fromdate = CONVERT(varchar(10),@fromdate,111)
SET @todate = DATEADD(d, 1, CONVERT(varchar(10),@todate,111))
SET @todate = DATEADD(ms,-2,@todate) -- end of date (23:59:59.999)

IF @empid IS NOT NULL
	BEGIN
		INSERT INTO #TotalDaysRequestInMonth (empid,TotalDaysRequest) 
		SELECT @empid , count(1) 
		FROM dbo.WorkingTimeRequest wt WITH (NOLOCK)
			INNER JOIN [dbo].[KeepInViewRequest] rq WITH (NOLOCK) 
				ON wt.RequestId = rq.RequestId
			WHERE wt.EmpId = @empid
				and wt.currentstatus = 6 
				and (month(rq.FromDate) = month(@fromdate) AND month(rq.ToDate) = month(@todate) )
	END
ELSE
	BEGIN
		INSERT INTO #TotalDaysRequestInMonth (empid,TotalDaysRequest) 
		SELECT wt.empid , count(1) 
		FROM dbo.WorkingTimeRequest wt WITH (NOLOCK)
			INNER JOIN [dbo].[KeepInViewRequest] rq WITH (NOLOCK) 
				ON wt.RequestId = rq.RequestId
			INNER JOIN Employee ee WITH (NOLOCK)
				ON ee.EmpId = wt.EmpId
			WHERE wt.currentstatus = 6
				and ee.GroupId IN (SELECT GroupId FROM #GroupsList )
				and (month(rq.FromDate) = month(@fromdate) OR month(rq.ToDate) = month(@todate) )
		GROUP BY wt.empid
	END

DECLARE @SQL VARCHAR(8000)
SET @SQL = 'SELECT 
	r.RequestId,
	RequestType,
	s.ShiftID,
	s.Code AS Shift,
	kiv.FromDate OnDate,
	kiv.[FromTime],
	kiv.[ToTime],
	kiv.IsHalfDay,
	Remark,
	r.CreatedDate,
	currentstatus Status,	
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
	ISNULL(rm.TotalDaysRequest,0) TotalDaysRequest,
	kiv.RefNo ,
	r.ModifiedBy ModifiedByID,
	e_m.NickName as ModifiedBy,
	e_m.FullName as FullNameModified,
	r.ModifiedDate
FROM  dbo.WorkingTimeRequest r WITH (NOLOCK)
	INNER JOIN [dbo].[KeepInViewRequest] kiv WITH (NOLOCK) ON r.RequestId = kiv.RequestId
	LEFT JOIN [dbo].Employee ap_V WITH (NOLOCK) ON ap_V.empid = r.VerifierId
	LEFT JOIN [dbo].Employee ap_A WITH (NOLOCK) ON ap_A.empid = r.ApproverId
	LEFT JOIN [dbo].Employee ap_H WITH (NOLOCK) ON ap_H.empid = r.HRId
	LEFT JOIN Employee e_m WITH (NOLOCK) ON e_m.empID = r.ModifiedBy
	LEFT JOIN Employee e WITH (NOLOCK) ON e.empID = r.empID	'+ CHAR(13)
	+ CASE WHEN @isLocal IS NOT NULL THEN 'LEFT JOIN dbo.EmployeeSummary e_s WITH (NOLOCK) ON e_s.EmpId = e.EmpId  ' ELSE '' END
+'	LEFT JOIN [dbo].EmployeeCalendar C WITH (NOLOCK) ON c.empid=r.empid and c.WorkDate BETWEEN kiv.FromDate AND kiv.ToDate 
	LEFT JOIN [dbo].[Shift] s WITH (NOLOCK) ON s.ShiftID = kiv.ShiftID	
	LEFT JOIN [Group] g WITH (NOLOCK) ON e.GroupID = g.GroupID
	LEFT JOIN  #TotalDaysRequestInMonth rm ON r.empID = rm.empid
WHERE (r.CreatedDate >= '''+ CONVERT(NVARCHAR(20),@fromdate )+''' AND r.CreatedDate <= ''' + CONVERT(NVARCHAR(20),@todate)+ ''')' + CHAR(13)
	+'			AND r.RequestType in (7) ' + CHAR(13)
	+ CASE WHEN @empid is null THEN '' ELSE '   and r.empid = ' + CONVERT(NVARCHAR(13),@empid)+ '  ' +CHAR(13) END
	+'			AND (e.isDeleted is null or e.isDeleted = 0)'+CHAR(13)
	+ CASE WHEN @excludedEmpID is null THEN '' ELSE '   and r.empid <> ' + CONVERT(NVARCHAR(13),@excludedEmpID)+ '  ' +CHAR(13) END
	+ CASE WHEN @status is null or @status ='' THEN '' ELSE '			and r.currentstatus IN (SELECT Currentstatus FROM #status ) ' +CHAR(13) END
	+ CASE WHEN @groupids ='' THEN '' ELSE '			and e.GroupId IN (SELECT GroupId FROM #GroupsList ) ' +CHAR(13) END
--	+'			and dbo.fnc_WorkingTimeRequest_GetRequestByDate_IsOutOfRange(kiv.OnDate,kiv.OnDate,''' 
--				+ CONVERT(NVARCHAR(20),@fromdate )+''',''' + CONVERT(NVARCHAR(20),@todate)+ ''')=0' + CHAR(13)
	+ CASE WHEN @RoleType IN (1,6) THEN ''
			WHEN @RoleType = 2 THEN 
					' AND( r.VerifierId =' + CONVERT(NVARCHAR(13),@SupervisorID) + ' OR  e.GroupID =' + @sGroupID  + ') ' + CHAR(13)
			WHEN @RoleType = 3 THEN 
						' AND ( r.ApproverId =' + CONVERT(NVARCHAR(13),@SupervisorID)  + ' OR e.GroupID =' + @sGroupID  + ')'+ CHAR(13)
			WHEN @RoleType = 23 THEN ' AND (r.ApproverId =' + CONVERT(NVARCHAR(13),@SupervisorID) 
										+' OR	r.VerifierId =' + CONVERT(NVARCHAR(13),@SupervisorID) 
										+' OR e.GroupID =' + @sGroupID  + ')'+ CHAR(13)
			END
	+ CASE WHEN @isLocal IS NOT NULL THEN ' AND  e_s.IsLocal = ' + CONVERT(NVARCHAR(10),@isLocal) + CHAR(13)  ELSE '' END
+'			ORDER BY r.CreatedDate DESC'

IF @isDebug = 1 PRINT @SQL 
IF @isDebug = 1 PRINT @RoleType
EXEC (@SQL )

DROP TABLE #TotalDaysRequestInMonth
DROP TABLE #GroupsList
DROP TABLE #RolesList
DROP TABLE #status