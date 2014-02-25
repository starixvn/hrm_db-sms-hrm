USE HRM_SMS
GO
/****** Object:  StoredProcedure [dbo].[WorkingTimeRequest_GetRequestByDate_AllType]    Script Date: 2013-11-04 10:31:47 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].OverTime_GetRequestYearlyByHR
	@SupervisorID INT,
	@empid int = null,
	@groupids varchar(max) = '',
	@Year int = null,
	@status varchar(max) = '4,6',
	@excludedEmpID int= null,
	@role varchar(max) = '6',

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

DECLARE @fromdate VARCHAR(25),	@todate VARCHAR(25)

SELECT @fromdate = CONVERT(VARCHAR(10),@Year) + '/01/01 00:00:00',
		@todate  = CONVERT(VARCHAR(10),@Year) + '/12/31 23:59:59'

IF (ISDATE(@fromdate) = 0 OR ISDATE(@todate) = 0)
BEGIN
	SELECT @ErrCode=100,@ErrMsg='Parameter invalid.'
	PRINT @ErrMsg
	RETURN
END

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
		INSERT INTO #RolesList (roleid)
		SELECT val FROM fnc_strSplit (@role, ',')
	
	SET @role = 1
	SELECT @role = Roles FROM dbo.Employee WITH(NOLOCK) WHERE EmpId = @SupervisorID

	IF EXISTS(SELECT TOP 1 1 FROM #RolesList WHERE roleid = 6)
		BEGIN 
			IF @role LIKE '%6%'
				SET @RoleType=6
			ELSE
				BEGIN
					SELECT @ErrCode=101,@ErrMsg='You don''t have permission on this funcion.(6)'
					PRINT @ErrMsg + @role
					RETURN
				END
		END
	ELSE IF 2=(SELECT COUNT(1) FROM #RolesList WHERE roleid in (2,3))
		BEGIN 
			IF @role LIKE '%2%' AND @role LIKE '%3%' 
				SET @RoleType=23
			ELSE IF @role LIKE '%2%'
				SET @RoleType=2
			ELSE IF @role LIKE '%3%'
				SET @RoleType=3
			ELSE
				BEGIN
					SELECT @ErrCode=102,@ErrMsg='You don''t have permission on this funcion.(2,3)'
					PRINT @ErrMsg + @role
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
					SELECT @ErrCode=103,@ErrMsg='You don''t have permission on this funcion.(2)'
					PRINT @ErrMsg + @role
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
					SELECT @ErrCode=104,@ErrMsg='You don''t have permission on this funcion.(3)'
					PRINT @ErrMsg
					RETURN
				END
				--SET @RoleType=1 
		END
	ELSE
		BEGIN
			SET @RoleType=1
			SELECT @ErrCode=105,@ErrMsg='You don''t have permission on this funcion.'
			PRINT @ErrMsg + @role
			RETURN
		END
END
ELSE 
	BEGIN
		SET @RoleType=1
		SELECT @ErrCode=106,@ErrMsg='You don''t have permission on this funcion.(1)'
		PRINT @ErrMsg + @role
		RETURN
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

CREATE  TABLE #Calendar(_MONTH INT,isDeleted BIT)
DECLARE @FromMonth INT=1,@ToMonth INT=12

WHILE (@FromMonth <= @ToMonth )
BEGIN
	INSERT INTO #Calendar(_MONTH)
	VALUES (@FromMonth)
	SET @FromMonth =@FromMonth +1
END

DECLARE @SQL VARCHAR(8000)
SET @SQL = 
'		SELECT empID,Code,NickName,FullName,Team,TeamCode,
			[1] Jan,[2] Feb,[3] Mar,[4] Apr,[5] May,[6] Jun,[7] Jul,[8] Aug,[9] Sep,[10] Oct,[11] Nov,[12] Dec,
			(ISNULL([1],0)+ISNULL([2],0)+ISNULL([3],0)+ISNULL([4],0)
			+ISNULL([5],0)+ISNULL([6],0)+ISNULL([7],0)+ISNULL([8],0)
			+ISNULL([9],0)+ISNULL([10],0)+ISNULL([11],0)+ISNULL([12],0)) AS Total
		FROM
		(
		SELECT 
						e.empID,
						e.Code AS Code,
						e.NickName AS NickName,
						e.FullName AS FullName,
						g.Name AS Team,
						g.Code AS TeamCode,
						cl._MONTH AS [Month],				
						(ot.[NormalHours]+ot.[OffHours]+ot.[PublicHours])ToTalHours

 FROM #Calendar cl 
	LEFT JOIN [dbo].[OTMonthlyRequest] ot WITH (NOLOCK) ON cl._MONTH = Month(Ot.Month)
	LEFT JOIN Employee e WITH (NOLOCK) ON e.empID = ot.empID	
	LEFT JOIN [Group] g WITH (NOLOCK) ON e.GroupID = g.GroupID
		WHERE (ot.Month >= ''' + @FromDate + ''' AND	ot.Month  <= ''' + @todate + ''') '+CHAR(13)
	+ CASE WHEN @empid is null THEN '' ELSE '   and ot.empid = ' + CONVERT(NVARCHAR(13),@empid)+ '  ' +CHAR(13) END
	+ CASE WHEN @excludedEmpID is null THEN '' ELSE '   and ot.empid <> ' + CONVERT(NVARCHAR(13),@excludedEmpID)+ '  ' +CHAR(13) END
	+ CASE WHEN @status is null or @status ='' THEN '' ELSE '			and ot.currentstatus IN (SELECT Currentstatus FROM #status ) ' +CHAR(13) END
	+ CASE WHEN @groupids ='' THEN '' ELSE '		and e.GroupId IN (SELECT GroupId FROM #GroupsList ) ' +CHAR(13) END
	+ CASE WHEN @RoleType IN (6) THEN ''
			WHEN @RoleType = 2 THEN ' AND ot.VerifierId =' + CONVERT(NVARCHAR(13),@SupervisorID) + CHAR(13)
			WHEN @RoleType = 3 THEN ' AND ot.ApproverId =' + CONVERT(NVARCHAR(13),@SupervisorID) + CHAR(13)
			WHEN @RoleType = 23 THEN ' AND (ot.ApproverId =' + CONVERT(NVARCHAR(13),@SupervisorID) 
										+' OR	ot.VerifierId =' + CONVERT(NVARCHAR(13),@SupervisorID) + ')'+ CHAR(13)
			END
	+'	) AS tmp
 Pivot
 (
	MAX(ToTalHours) FOR [Month] IN ([1],[2],[3],[4],[5],[6],[7],[8],[9],[10],[11],[12])
 )AS tmp2 
 WHERE 
	empID IS NOT NULL '
	
	IF @isDebug = 1 PRINT @SQL 
	IF @isDebug = 1 PRINT @RoleType
	EXEC (@SQL )

SELECT @ErrCode=0,@ErrMsg=''

DROP TABLE #GroupsList
DROP TABLE #RolesList
DROP TABLE #status
DROP TABLE #Calendar