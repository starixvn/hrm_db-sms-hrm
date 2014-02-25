USE HRM_SMS
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Overtime_SET_OTSum]
	@EmpId VARCHAR(8000), 
	@Month datetime=NULL,

	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(200) = '' OUTPUT,
	@IsDebug  BIT=0
AS
/*
Created: Tom.Vo@2013-11-04
Task: insert Over time Sum
DB: HRM_SMS
Original: 

Revisions:
Param's Explanation:

*/
SET NOCOUNT ON;

IF LEN(ISNULL(@EmpId,''))=0
BEGIN
	SET @ErrCode =104
	SET @ErrMsg = 'Invalid parameter'
	RETURN;
END

SELECT @Month =CONVERT(VARCHAR(10),YEAR(@Month)) + '/' + CONVERT(VARCHAR(10),MONTH(@Month)) + '/01 00:00:00'

DECLARE @FromDate datetime,@ToDate datetime

SET @FromDate=@Month
SET @ToDate = DateADd(MONTH,1,@Month)
SET @ToDate = DateADd(DAY,-1,@ToDate )

IF OBJECT_ID('tempdb..#EmpId') IS NOT NULL
		DROP TABLE #EmpId

CREATE TABLE #EmpId (EmpID INT)

INSERT INTO #EmpId (EmpID)
	SELECT val FROM fnc_strSplit (@EmpId, ',')

BEGIN
		UPDATE OTSum
		SET 
				OTSum.[NormalHours] = ISNULL(rd.[NormalHours],0),
				OTSum.[OffHours] = ISNULL(rd.[OffHours],0),
				OTSum.[PublicHours]=ISNULL(rd.[PublicHours],0)
		FROM  [dbo].[OTMonthlySum] OTSum WITH(ROWLOCK,UPDLOCK)
			INNER JOIN (
				SELECT @Month [Month],rd.EmpID,
					SUM(ISNULL(OT.[NormalHours],0)) [NormalHours] ,SUM(ISNULL(OT.[OffHours],0)) [OffHours] ,SUM(ISNULL(OT.[PublicHours],0)) [PublicHours]
				FROM #EmpId rd
					INNER JOIN dbo.OTDailyRequest OT WITH(NOLOCK)
						ON (OT.OvertimeDate BETWEEN @FromDate AND @ToDate)
							AND OT.EmpId = rd.EmpID
							AND OT.Status IN (4,6)
					INNER JOIN dbo.OTMonthlyRequest  OTM WITH(NOLOCK)
						ON OTM.RequestId = OT.RequestId
							AND OTM.CurrentStatus IN (4,6)
				GROUP BY rd.EmpID
				)	rd		
				ON rd.EmpID = OTSum.EmpID AND OTSum.[Month] = rd.[Month]

		DELETE rd 
		 FROM #EmpId rd  
			INNER JOIN [dbo].[OTMonthlySum] OTSum WITH(NOLOCK) 
			ON rd.EmpID = OTSum.EmpID AND OTSum.[Month] = @Month

END

IF NOT EXISTS (SELECT TOP 1 1 FROM [dbo].[OTMonthlySum] OTSum WITH(NOLOCK) 
					INNER JOIN #EmpId rd  WITH(NOLOCK) 
							ON rd.EmpID = OTSum.EmpID AND OTSum.[Month] = @Month
			)
BEGIN
	INSERT INTO [dbo].[OTMonthlySum] (
		  [Month]
		  ,[EmpId]
		  ,[NormalHours]
		  ,[OffHours]
		  ,[PublicHours]
		)
	SELECT @Month [Month],rd.EmpID,
			SUM(ISNULL(OT.[NormalHours],0)) [NormalHours] ,SUM(ISNULL(OT.[OffHours],0)) [OffHours] ,SUM(ISNULL(OT.[PublicHours],0)) [PublicHours]
		FROM #EmpId rd
			INNER JOIN dbo.OTDailyRequest OT WITH(NOLOCK)
				ON (OT.OvertimeDate BETWEEN @FromDate AND @ToDate)
					AND OT.EmpId = rd.EmpID
					AND OT.Status IN (4,6)
			INNER JOIN dbo.OTMonthlyRequest OTM WITH(NOLOCK)
						ON OTM.RequestId = OT.RequestId
							AND OTM.CurrentStatus IN (4,6)
		GROUP BY rd.EmpID
END

 IF @@ERROR <> 0 
	BEGIN
		SELECT ERROR_MESSAGE()
		SELECT @ErrCode = 101, @ErrMsg = N'Create overtime request for an employee failed.'
		RETURN
	END
ELSE 
	SELECT @ErrCode=0,@ErrMsg=''

DROP TABLE #EmpID
