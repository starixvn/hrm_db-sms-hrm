USE HRM_SMS
GO
/****** Object:  StoredProcedure [dbo].[TimeRecord_ImportData]    Script Date: 2013-12-26 1:50:02 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[TimeRecord_ImportData]
AS
-- =============================================
-- Author:		Quinn.Vo
-- Create date: 2013/06/20
-- Description:	Import data replace for Job (in case use SQL Express is can not create job)
-- =============================================
BEGIN
	SET NOCOUNT ON;
	DECLARE @fromdate DATETIME, @todate DATETIME
	-- DECLARE @dw INT, @hour INT 

	SET @todate= CONVERT(VARCHAR(10), getdate(), 111)
	-- SET @dw=datepart(dw, @date)
	-- SET @hour=datepart(hh, @date)

	-- only run on Monday
	--IF (@dw=2 and @hour<= 12)
	--BEGIN
	--	SET @fromdate = dateadd(d,-3 ,@date)
	--	SET @todate = dateadd(d,-2 ,@date)
	--	EXEC dbo.TimeRecord_ImportFromBioAdmin @fromdate, @todate 
	--END
	-- end only run on Monday

	-- run for yesterday and today
	SET @fromdate = dateadd(d, -1 , @todate)
	EXEC dbo.TimeRecord_ImportFromBioAdmin @fromdate, @todate
-- EXEC dbo.EmployeeAttendance_ProcessingAndInsert null, @fromdate, @date
	-- end yesterday and today

END
