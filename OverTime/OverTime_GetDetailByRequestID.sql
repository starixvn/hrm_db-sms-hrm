USE HRM_SMS
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Overtime_GetDetailByRequestID] 
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

	DECLARE @fromDate NVARCHAR(100),@toDate NVARCHAR(100), @Month DATETIME

	SELECT TOP 1 @Month =  MAX(ot.OvertimeDate)
	FROM [dbo].[OTDailyRequest] ot WITH (NOLOCK)
	WHERE ot.RequestId = @RequestID

	SELECT @Month = CASE WHEN DAY(@Month) BETWEEN 10 AND 31 THEN DATEADD(MONTH,1,@Month) ELSE @Month  END
	
	SELECT @toDate = @Month, @fromDate = DATEADD(month,-1,@Month)

	SELECT @fromDate = CONVERT(VARCHAR(10),YEAR(@fromDate)) + '/' + CONVERT(VARCHAR(10),MONTH(@fromDate)) + '/10 00:00:00',
		@toDate =  CONVERT(VARCHAR(10),YEAR(@toDate)) + '/' + CONVERT(VARCHAR(10),MONTH(@toDate)) + + '/09 00:00:00'
 
	IF OBJECT_ID('tempdb..#Calendar') IS NOT NULL
		DROP TABLE #Calendar

	CREATE TABLE #Calendar(WorkDate datetime,[Enabled] BIT,IsDeleted BIT)

	WHILE (@fromDate<=@toDate) 
		BEGIN
			INSERT INTO #Calendar(WorkDate,[Enabled],IsDeleted) VALUES(@fromDate,1,0)
			SET @fromDate=CONVERT(VARCHAR(10),CONVERT(DATETIME,@fromDate)+1,111)+ ' 00:00:00'
		END

	SELECT @fromDate = DATEADD(month,-1,@Month)
	SELECT @fromDate = CONVERT(VARCHAR(10),YEAR(@Month)) + '/' + CONVERT(VARCHAR(10),MONTH(@Month)) + '/09 00:00:00'

	SELECT tmp.WorkDate [OvertimeDate]
		,ot.[EmpId]
		,ot.[RequestId]
		,s.Code [Schedule]
		,CASE WHEN ot.[TimeIn] IS NULL OR s.ShiftId  IS NULL THEN NULL ELSE CONVERT(VARCHAR(5),ot.[TimeIn],108) END [TimeIn]
		,CASE WHEN ot.[TimeOut] IS NULL OR s.ShiftId  IS NULL THEN NULL ELSE CONVERT(VARCHAR(5),ot.[TimeOut],108) END [TimeIn]
		,ot.[TotalHours]
		,ot.[NormalHours]
		,ot.[OffHours]
		,ot.[PublicHours]
		,ot.[Remark]
		,ot.[Status]
		,ot.[IsUpdated]
	FROM [dbo].[OTDailyRequest] ot WITH (NOLOCK)
	RIGHT JOIN  #Calendar tmp ON tmp.WorkDate = ot.OvertimeDate
	LEFT JOIN dbo.[Shift] s WITH (NOLOCK) ON s.ShiftId = ot.[Schedule]
	WHERE ot.RequestId = @RequestID
	ORDER BY WorkDate

	DROP TABLE #Calendar
END
