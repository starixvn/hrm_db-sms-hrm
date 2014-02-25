--USE [HRM_SMS]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].OverTime_GetNormalDailyByHR
	@SupervisorID INT,
	@EmpID INT,
	@Month datetime,
	@role varchar(max) = '6',
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


	DECLARE @fromDate NVARCHAR(100),@toDate NVARCHAR(100)
		
	SELECT @fromDate = CONVERT(VARCHAR(10),YEAR(@Month)) + '/' + CONVERT(VARCHAR(10),MONTH(@Month)) + '/01 00:00:00'
	SELECT @toDate = DATEADD(DAY,-1,DATEADD(Month,1,@fromDate))
 
	IF OBJECT_ID('tempdb..#Calendar') IS NOT NULL
		DROP TABLE #Calendar

	CREATE TABLE #Calendar(WorkDate datetime,[Enabled] BIT,IsDeleted BIT)

	WHILE (CONVERT(DATETIME,@fromDate)<=CONVERT(DATETIME,@toDate)) 
		BEGIN
			INSERT INTO #Calendar(WorkDate,[Enabled],IsDeleted) VALUES(@fromDate,1,0)
			SET @fromDate=CONVERT(VARCHAR(10),CONVERT(DATETIME,@fromDate)+1,111)+ ' 00:00:00'
		END

	SELECT @fromDate = CONVERT(VARCHAR(10),YEAR(@Month)) + '/' + CONVERT(VARCHAR(10),MONTH(@Month)) + '/01 00:00:00'


	SELECT tmp.WorkDate [OvertimeDate]
		,ISNULL(ot.[EmpId],@EmpID) AS [EmpId]
		,ot.[RequestId]
		,ISNULL(s.ShiftId,sc.ShiftId) [ShiftId]
		,ISNULL(s.TotalHours,sc.TotalHours) [TotalShiftHours]
		,ISNULL(s.Code,sc.Code) [Schedule]
		,CASE WHEN ot.[TimeIn] IS NULL OR s.ShiftId  IS NULL THEN 
				CASE WHEN ec.InFixed IS NULL OR sc.ShiftId  IS NULL THEN NULL ELSE CONVERT(VARCHAR(5),ec.InFixed,108) END
			ELSE CONVERT(VARCHAR(5),ot.[TimeIn],108) END [TimeIn]
		,CASE WHEN ot.[TimeOut] IS NULL OR s.ShiftId  IS NULL THEN 
				CASE WHEN ec.OutFixed IS NULL OR sc.ShiftId  IS NULL THEN NULL ELSE CONVERT(VARCHAR(5),ec.OutFixed,108) END
			ELSE CONVERT(VARCHAR(5),ot.[TimeOut],108) END [TimeOut]
		,ISNULL(ot.[TotalHours],CASE WHEN sc.ShiftId  IS NULL THEN NULL  ELSE CONVERT(NVARCHAR(10),convert(int,ec.TotalWorkHours) ) +'.'+	
															REPLICATE('0',2-LEN(CONVERT(NVARCHAR(10),convert(int,round((ec.TotalWorkHours%1)*60,0)))) )
															+CONVERT(NVARCHAR(10),convert(int,round((ec.TotalWorkHours%1)*60,0))) END) [TotalWorkHours]
		,ot.[NormalHours]
		,ot.[OffHours]
		,ot.[PublicHours]
		,ot.[Remark]
		,ot.[Status]
		,ot.[IsUpdated]
		,ecl.IsHoliday
		,ecl.IsOffDay
		,ecl.IsKeepInView
	FROM #Calendar tmp
	LEFT JOIN [dbo].[OTDailyRequest] ot WITH (NOLOCK) ON tmp.WorkDate = ot.OvertimeDate AND ot.EmpID = @EmpID
	LEFT JOIN dbo.[Shift] s WITH (NOLOCK) ON s.ShiftId = ot.[Schedule]
	LEFT JOIN dbo.EmployeeAttendance ec WITH (NOLOCK)
		ON ec.AttendanceDate =  tmp.WorkDate  AND  ec.EmpId =@EmpID
	LEFT JOIN dbo.EmployeeCalendar ecl WITH(NOLOCK) 
		ON ecl.WorkDate = tmp.WorkDate AND ecl.EmpId = @EmpId
	LEFT JOIN dbo.[Shift] sc WITH (NOLOCK) ON sc.ShiftId = ec.ShiftId
	--WHERE (OvertimeDate BETWEEN @fromDate AND @toDate) 
	ORDER BY tmp.WorkDate 
 

	DROP TABLE #Calendar
	SELECT @ErrCode = 0,@ErrMsg = ''
END

/*
declare @p14 int,@p3 int
declare @p15 nvarchar(200)
declare @fromtime datetime,@totime datetime

SELECT @p15=N'',@p14=0
SET @fromtime='20131118'
SET @totime=@fromtime+7

exec [dbo].[Overtime_GetInOutMonthlyByEmpId]
	@EmpID =139,
	@Month = '20131101'
 ,@ErrCode = @p14 OUTPUT
 ,@ErrMsg = @p15 OUTPUT

SELECT @p3,@p14,@p15

*/