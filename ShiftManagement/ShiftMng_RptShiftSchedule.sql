--USE [HRM_SMS]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[ShiftMng_RptShiftSchedule]
	@SupervisorID INT=NULL,
	@fromtime datetime, 
	@totime datetime, 
	@groupIds varchar(max) = '',
	
	@isShowWholeCompany bit = 0,
	@isLocal bit = NULL,

	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(200) = '' OUTPUT,

	@isDebug BIT=0
AS
/*
Created: Tom.Vo@2013-10-23
Task: Get Shift Scheduling Report
DB: HRM_SMS
Original: 

Revisions:  
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;
	DECLARE @fromDate NVARCHAR(100),@toDate NVARCHAR(100)

	SELECT @fromDate = CONVERT(VARCHAR(10),@fromtime,111) + ' 00:00:00',
		@toDate = CONVERT(VARCHAR(10),@totime,111) + ' 00:00:00'

	IF (DATEPART(dw,@fromDate)<>2 OR DATEPART(dw,@toDate)<>1 OR DATEDIFF(dd,@fromdate,@toDate)<>6 OR @SupervisorID IS NULL)
	BEGIN
		SELECT @ErrCode = 100,@ErrMsg = N'Parameter not correct.'
		RETURN
	END

	--IF (DATEDIFF(dd,getdate(),@fromdate)<0)
	--BEGIN
	--	SELECT @ErrCode = 100,@ErrMsg = N'Parameter not correct.'
	--	RETURN
	--END

	IF @SupervisorID IS NOT NULL
		IF NOT EXISTS(SELECT TOP 1 1 FROM dbo.Employee ee (NOLOCK) WHERE EmpId = @SupervisorID AND (Roles LIKE '%4%' OR Roles LIKE '%6%'))
		BEGIN
			SELECT @ErrCode = 102,@ErrMsg = N'You don''t have permission on the funcion.'
			RETURN
		END

	CREATE TABLE #GroupsList (GroupId TINYINT)

	IF ISNULL(@groupids,'') <>''
	INSERT INTO #GroupsList (GroupId)
		SELECT g.val 
		FROM fnc_strSplit (@groupids, ',') AS g
			--INNER JOIN dbo.GroupSupervisor gs WITH (NOLOCK) 
			--		ON g.val = gs.GroupId
			--WHERE gs.OwnerId = @EmpID AND gs.ActionType = 4
	ELSE
		BEGIN
			INSERT INTO #GroupsList (GroupId)
			SELECT g.GRoupID FROM dbo.[Group] g WITH (NOLOCK)
			--	INNER JOIN dbo.GroupSupervisor gs WITH (NOLOCK) 
			--		ON g.GroupId = gs.GroupId
			--WHERE gs.OwnerId = @EmpID AND gs.ActionType = 4
		END

	DECLARE @SQL NVARCHAR(4000), @sWhere NVARCHAR(4000),@bWhere bit

	SELECT @sWhere = '',@bWhere = 0

	IF ISNULL(@groupids,'') <> ''
		SELECT @sWhere = @sWhere + CASE WHEN @bWhere = 1 THEN ' AND ' ELSE ' WHERE ' END 
				+ ' ( e.GroupId IN (SELECT GroupId FROM #GroupsList) )' + CHAR(13) 
					, @bWhere = 1

CREATE TABLE #tmpSchedule(
	GroupId INT,
	ShiftId INT,
	[Weekday] INT,
	[Total] INT)

	SELECT @SQL ='INSERT INTO #tmpSchedule (GroupId,ShiftId,[Weekday],[Total])
				SELECT e.GroupId,ISNULL(ec.ShiftId,0),DATEPART(dw,ec.WorkDate) [Weekday], Count(1) ToTal ' + CHAR(13) 
				+'FROM dbo.Employee e WITH (NOLOCK)  ' + CHAR(13) 
				+CASE WHEN ISNULL(@isShowWholeCompany,1)=1 THEN ''
					ELSE '	INNER JOIN dbo.EmployeeSupervisor es WITH(NOLOCK)  ' + CHAR(13) 
						+'		ON e.EmpId = es.OwnerID AND es.EmpID = ' + CONVERT(NVARCHAR(10),@SupervisorID) + ' AND es.ActionType=4 ' + CHAR(13) 
					END
				+'	INNER JOIN dbo.EmployeeCalendar ec WITH (NOLOCK)  ' + CHAR(13) 
				+'		ON e.EmpId = ec.EmpId  ' + CHAR(13) 
				+ CASE WHEN @isLocal IS NOT NULL THEN 'LEFT JOIN dbo.EmployeeSummary e_s WITH (NOLOCK) ON e_s.EmpId = e.EmpId  ' ELSE '' END
				+'WHERE (ec.WorkDate BETWEEN ''' + @fromDate + ''' AND ''' + @toDate + ''' ) ' + CHAR(13) 
				+	CASE WHEN @bWhere = 1 THEN REPLACE(@sWhere,'WHERE','AND') ELSE '' END
				+'	AND (ISNULL(ec.ShiftId,0) <> 0 ) '+ CHAR(13)
				+ CASE WHEN @isLocal IS NOT NULL THEN ' AND  e_s.IsLocal = ' + CONVERT(NVARCHAR(10),@isLocal) + CHAR(13)  ELSE '' END
				+'GROUP BY  e.GroupId,ISNULL(ec.ShiftId,0),DATEPART(dw,ec.WorkDate)' + CHAR(13)
	EXEC sp_executesql  @SQL 

	IF @isDebug = 1 PRINT @SQL 
	
	set @SQL = 'SELECT --GroupId, Name, 
			ShiftId, Color ,Code,[2] AS [Monday],[3] AS [Tuesday],[4] AS [Wednesday],[5] AS [Thursday],[6] AS [Friday],[7] AS [Saturday],[1] AS [Sunday] '+ CHAR(13) 
	+' FROM (' + CHAR(13) 
	+' 	SELECT --tmp.GroupId, g.Name, 
			tmp.ShiftId, s.Color,s.Code,tmp.[Weekday],tmp.ToTal '+ CHAR(13) 
	+' 	FROM #tmpSchedule tmp ' + CHAR(13) 
	+' 		LEFT JOIN dbo.[Group] g WITH (NOLOCK)' + CHAR(13) 
	+'			ON tmp.GroupID = g.GroupID ' + CHAR(13) 
	+' 		LEFT JOIN dbo.[Shift] s WITH (NOLOCK)' + CHAR(13) 
	+'			ON s.ShiftId = tmp.ShiftId ' + CHAR(13) 
	+'		) tmp ' + CHAR(13) 
	+'PIVOT' + CHAR(13) 
	+'(
		MAX(ToTal) FOR [Weekday] IN ([2],[3],[4],[5],[6],[7],[1])' + 
	') AS pvt'

	IF @isDebug = 1 PRINT @SQL 
	EXEC sp_executesql  @SQL 

	DROP TABLE #GroupsList
	DROP TABLE #tmpSchedule

SELECT @ErrCode = 0	
END
