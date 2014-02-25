
GO
/****** Object:  StoredProcedure [dbo].[ShiftMng_GetShiftSchedule]    Script Date: 2014-02-17 3:36:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[ShiftMng_GetShiftSchedule]
	--@query nvarchar(256),
	@SupervisorID INT,
	@EmpID INT=NULL,
	@fromtime datetime, 
	@totime datetime, 
	@groupIds varchar(max) = '',
	@JobTitleId varchar(1000) = '',

	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(200) = '' OUTPUT,
	@isDebug BIT=0
AS
/*
Created: Tom.Vo@2013-10-23
Task: Get Shift Scheduling
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

	IF (DATEPART(dw,@fromDate)<>2 OR DATEPART(dw,@toDate)<>1 OR DATEDIFF(dd,@fromdate,@toDate)<>6)
	BEGIN
		SELECT @ErrCode = 100,@ErrMsg = N'Parameter not correct.'
		RETURN
	END

	--IF (DATEDIFF(dd,getdate(),@fromdate)<0)
	--BEGIN
	--	SELECT @ErrCode = 100,@ErrMsg = N'Parameter not correct.'
	--	RETURN
	--END

	IF NOT EXISTS(SELECT TOP 1 1 FROM dbo.Employee ee (NOLOCK) WHERE EmpId = @SupervisorID AND Roles LIKE '%4%')
	BEGIN
		SELECT @ErrCode = 102,@ErrMsg = N'You don''t have permission on the funcion.'
		RETURN
	END

	CREATE TABLE #Calendar(WorkDate datetime,[Enabled] BIT,IsDeleted BIT)

	WHILE (@fromDate<=@toDate) 
		BEGIN
			INSERT INTO #Calendar(WorkDate,[Enabled],IsDeleted) VALUES(@fromDate,1,0)
			SET @fromDate=CONVERT(VARCHAR(10),CONVERT(DATETIME,@fromDate)+1,111)+ ' 00:00:00'
		END

	SELECT @fromDate = CONVERT(VARCHAR(10),@fromtime,111) + ' 00:00:00'
	CREATE CLUSTERED INDEX IDX_C_Calendar_DeviceID ON #Calendar(WorkDate)
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

	IF @EmpID IS NOT NULL
		SELECT @sWhere = @sWhere + CASE WHEN @bWhere = 1 THEN ' AND ' ELSE ' WHERE ' END 
					+ ' (e.EmpId = ' + CONVERT(NVARCHAR(10),@EmpID) +' )' + CHAR(13) 
					, @bWhere = 1

	IF ISNULL(@groupids,'') <> ''
		SELECT @sWhere = @sWhere + CASE WHEN @bWhere = 1 THEN ' AND ' ELSE ' WHERE ' END 
				+ ' ( e.GroupId IN (SELECT GroupId FROM #GroupsList) )' + CHAR(13) 
					, @bWhere = 1

	CREATE TABLE #JobTitleList (JobTitleId TINYINT)

	IF ISNULL(@JobTitleId,'')  <>''
		BEGIN 
			INSERT INTO #JobTitleList (JobTitleId)
			SELECT val FROM fnc_strSplit (@JobTitleId, ',')

			SELECT @sWhere = @sWhere + CASE WHEN @bWhere = 1 THEN ' AND ' ELSE ' WHERE ' END 
				+ ' ( e.JobTitleId IN (SELECT JobTitleId FROM #JobTitleList ) )' + CHAR(13) 
					, @bWhere = 1
		END

	SELECT @SQL ='SELECT ' + CHAR(13) 
				+'		tmp.WorkDate,DATEPART(dw,tmp.WorkDate) [Weekday], ' + CHAR(13) 
				+'		CASE WHEN ot.Status IN (2,4,6) THEN CONVERT(BIT,1) ELSE CONVERT(BIT,0) END IsOvertime,' + CHAR(13)
				+'		CASE WHEN wkr.RequestId IS NOT NULL AND lrd.WorkType = 1 THEN 1 ELSE 0 END IsLeaveOffday, ' + CHAR(13) 
				+'		CASE WHEN ec.ChangeShiftId IS NULL THEN 0 ELSE 1 END IsChangeShift, ' + CHAR(13) 
				+'		CASE WHEN ec.IsHoliday IS NOT NULL THEN ec.IsHoliday  
							WHEN  (esum.islocal =1 OR (esum.IsLocal = 0 AND esum.IsExpatUseHoliday=1 )) AND hld.HolidayName IS NOT NULL THEN 1 ELSE 0 END IsHoliday,' + CHAR(13) 
				+'		ec.IsOffDay ,ec.IsLeaveDay,ec.IsKeepInView,ISNULL(ec.LeaveDay,0) LeaveDay, IsPublic,' + CHAR(13)
				+'		s2.ShiftId ShiftMultipleID,s2.Code ShiftMultipleCode,s2.Name ShiftMultipleName, ee.NickName AS ModifierName, ec.ModifiedDate, ' + CHAR(13) 
				+'		ISNULL(esum.OffDaysbyWeek,0) OffDaysbyWeek,'   + CHAR(13) 
				+'		e.EmpId,e.NickName,e.FullName,g.GroupId,g.Code,g.Name,' + CHAR(13) 
				+'		ec.ShiftId,s.Code,s.Name,' + CHAR(13) 
				+'		lv.LeaveTypeId,lv.Code,lv.Name,' + CHAR(13)
				+'		lv2.LeaveTypeId AS LeaveTypeId2,lv2.Code,lv2.Name,' + CHAR(13)
				+'		e.JobTitleId [PositionID],lk.Name	[Positions]'   + CHAR(13) 
		
				+'FROM dbo.Employee e WITH (NOLOCK)  ' + CHAR(13) 
				+'	INNER JOIN dbo.EmployeeSupervisor es WITH(NOLOCK)  ' + CHAR(13) 
				+'		ON e.EmpId = es.OwnerID AND es.EmpID = ' + CONVERT(NVARCHAR(10),@SupervisorID) + ' AND es.ActionType=4 ' + CHAR(13) 
				+' 	INNER JOIN #Calendar tmp  ' + CHAR(13) 
				+'		ON e.[Enabled] = tmp.[Enabled] AND e.[IsDeleted] = tmp.[IsDeleted]' + CHAR(13) 
				+'	LEFT JOIN dbo.EmployeeCalendar ec WITH (NOLOCK)  ' + CHAR(13) 
				+'		ON ec.WorkDate =  tmp.WorkDate  AND  e.EmpId = ec.EmpId  ' + CHAR(13) 
				+'	LEFT JOIN dbo.EmployeeSummary esum WITH (NOLOCK)  ' + CHAR(13) 
				+'		ON esum.EmpId = e.EmpId AND esum.islocal = 1  ' + CHAR(13) 
				+'	LEFT JOIN dbo.OTDailyRequest ot WITH (NOLOCK)  ' + CHAR(13) 
				+'		ON ot.OvertimeDate =  tmp.WorkDate AND ot.EmpId = e.EmpId AND esum.islocal = 1  ' + CHAR(13) 
				+'	LEFT JOIN dbo.Holiday hld WITH (NOLOCK)  ' + CHAR(13) 
				+'		ON (hld.FromDate BETWEEN ''' + @fromDate+ ''' AND '''+ @toDate + ''''  + CHAR(13) 
				+'		OR hld.ToDate BETWEEN ''' + @fromDate+ ''' AND '''+ @toDate + ''')'  + CHAR(13) 
				+'		AND (tmp.WorkDate BETWEEN hld.FromDate AND hld.ToDate )'  + CHAR(13) 
				+'		LEFT JOIN dbo.LookupData lk		WITH(NOLOCK) 	ON e.JobTitleId=lk.Id and LookupId = 1'  + CHAR(13) 
				+'	LEFT JOIN dbo.Employee ee WITH (NOLOCK)  ' + CHAR(13) 
				+'		ON ec.ModifiedBy = ee.EmpId ' + CHAR(13) 
				+' 	LEFT JOIN dbo.[Group] g WITH (NOLOCK)' + CHAR(13) 
				+'		ON e.GroupID = g.GroupID ' + CHAR(13) 
				+' 	LEFT JOIN dbo.[Shift] s WITH (NOLOCK)' + CHAR(13) 
				+'		ON s.ShiftId = ec.ShiftId ' + CHAR(13) 
				+' 	LEFT JOIN dbo.LeaveType AS lv WITH (NOLOCK) ON ec.LeaveTypeId = lv.LeaveTypeId' + CHAR(13) 
				+' 	LEFT JOIN dbo.LeaveType AS lv2 WITH (NOLOCK) ON ec.LeaveTypeId2 = lv2.LeaveTypeId' + CHAR(13) 
				+'  --LEFT JOIN dbo.Shift AS s1 WITH (NOLOCK) ON ec.ChangeShiftId = s1.ShiftId' + CHAR(13) 
				+'    LEFT JOIN (
							SELECT tbl.ForDate, tbl.EmpID,spl.ShiftId
								FROM (
										SELECT MAX(ForDate)  ForDate, EmpID
										FROM dbo.EmployeeScheduleShiftMultiple  AS spl WITH (NOLOCK)
											WHERE ForDate <= ''' + @fromDate + ''' AND spl.ShiftId>0
										GROUP BY EmpID
									) tbl
							LEFT JOIN dbo.EmployeeScheduleShiftMultiple  AS spl WITH (NOLOCK)
								ON tbl.ForDate = spl.ForDate AND tbl.EmpID = spl.EmpID 
					)	spl  ON spl.ForDate <= tmp.WorkDate AND spl.EmpID = e.EmpID  ' + CHAR(13) 
				+'  LEFT JOIN dbo.Shift AS s2 WITH (NOLOCK) ON spl.ShiftId = s2.ShiftId' + CHAR(13) 
				+'  LEFT JOIN dbo.LeaveRequestDetail lrd WITH(NOLOCK) ON lrd.OnDate = ec.WorkDate AND lrd.EmpId = ec.EmpId AND lrd.WorkType IN (1,3)' + CHAR(13) 				+'  LEFT JOIN dbo.WorkingTimeRequest wkr WITH(NOLOCK) ON wkr.RequestId = lrd.RequestId AND wkr.CurrentStatus IN (4,6)' + CHAR(13) 
				+	CASE WHEN @bWhere = 1 THEN 'WHERE ' + CHAR(13)  + REPLACE(@sWhere,'WHERE','') ELSE '' END
				+'ORDER BY es.OrderNo ,tmp.WorkDate' + CHAR(13)  
				--+'ORDER BY es.OrderNo ,e.NickName,tmp.WorkDate' + CHAR(13)  
				--+'ORDER BY g.Name,es.OrderNo ,e.NickName,tmp.WorkDate' + CHAR(13)  
	IF @isDebug = 1 PRINT @SQL 

	EXEC sp_executesql  @SQL 

	
	
	DROP TABLE #GroupsList
	DROP TABLE #Calendar
	DROP TABLE #JobTitleList
END

/*
declare @p14 int,@p3 int
declare @p15 nvarchar(200)
declare @fromtime datetime,@totime datetime

SELECT @p15=N'',@p14=0
SET @fromtime='20131118'
SET @totime=@fromtime+7

exec [ShiftMng_GetShiftSchedule] @EmpID = 1 
 ,@query=N''
 ,@groupIds='1,2,4'
 ,@fromtime=@fromtime
 ,@totime=@totime
 ,@ErrCode = @p14 OUTPUT
 ,@ErrMsg = @p15 OUTPUT

SELECT @p3,@p14,@p15

*/