USE [HRM_SMS]
GO
/****** Object:  StoredProcedure [dbo].[Shift_GetShifts]    Script Date: 2013-10-29 4:23:13 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Shift_GetShiftsByShiftID]
	@ShiftID INT
AS
/*
Created: Tom.Vo@2013-10-23
Task: retrieve data on shift by ShiftID
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
*/
BEGIN
SET NOCOUNT ON;

SELECT [ShiftID]
      ,[Code]
      ,[Name]
      ,[BeginCheckInTime]
      ,[EndCheckInTime]
      ,[BeginCheckOutTime]
      ,[EndCheckOutTime]
      ,[BreakTimeMins]
      ,[OrderNo]
      ,[BeginBreakTime]
      ,[EndBreakTime]
	  ,CrossDay
	  ,Color
	  ,TotalHours
FROM [dbo].[Shift] WITH(NOLOCK)
WHERE ShiftID  = @ShiftID

END
