USE HRM_SMS
GO
/****** Object:  StoredProcedure [dbo].[WorkingTimeRequest_GetRequestByDate_AllType]    Script Date: 2013-11-04 10:31:47 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].OverTime_GetNormalMonthlyByHR
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
Task:Get  normal calendar  By Date For Overtime
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
*/
SET NOCOUNT ON;

SELECT @fromdate = CONVERT(VARCHAR(10),@fromDate,111) + ' 00:00:00',
		@todate = CONVERT(VARCHAR(10),@toDate,111) + ' 23:59:59'

CREATE TABLE #status (Currentstatus TINYINT)
IF LEN(ISNULL(@status,'')) = 0
	SET @status =  '4,6'

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
				r.empID,
				r.Month AS RequestDate,
				e.EmpId AS RequesterID,
				e.NickName AS Requester,
				e.FullName AS FullNameRequester,
				g.Name AS Team,
				g.Code AS TeamCode,

				r.[NormalHours],
			    r.[OffHours],
			    r.[PublicHours],
				(r.[NormalHours]+r.[OffHours]+r.[PublicHours]) ToTalHours

 FROM  [dbo].[OTMonthlySum] r WITH (NOLOCK)
				LEFT JOIN Employee e WITH (NOLOCK) ON e.empID = r.empID	
				
				LEFT JOIN [Group] g WITH (NOLOCK) ON e.GroupID = g.GroupID

		WHERE (e.isDeleted is null or e.isDeleted = 0)'+CHAR(13)
	+'   AND	r.Month >= ''' + CONVERT(NVARCHAR(20),@fromdate)+ ''' 
				and r.Month  <= ''' + CONVERT(NVARCHAR(20),@todate)+ ''''+CHAR(13)
	+ CASE WHEN @empid is null THEN '' ELSE '   and r.empid = ' + CONVERT(NVARCHAR(13),@empid)+ '  ' +CHAR(13) END
	+ CASE WHEN @excludedEmpID is null THEN '' ELSE '   and r.empid <> ' + CONVERT(NVARCHAR(13),@excludedEmpID)+ '  ' +CHAR(13) END
	--+ CASE WHEN @status is null or @status ='' THEN '' ELSE '			and r.currentstatus IN (SELECT Currentstatus FROM #status ) ' +CHAR(13) END
	+ CASE WHEN @groupids ='' THEN '' ELSE '		and e.GroupId IN (SELECT GroupId FROM #GroupsList ) ' +CHAR(13) END
	+'			ORDER BY r.Month DESC'
	
	IF @isDebug = 1 PRINT @SQL 
	IF @isDebug = 1 PRINT @RoleType
	EXEC (@SQL )

SELECT @ErrCode=0,@ErrMsg=''
	
DROP TABLE #GroupsList
DROP TABLE #RolesList
DROP TABLE #status
