USE HRM_SMS
GO
/****** Object:  StoredProcedure [dbo].[EmployeeCalendar_GetUnavailRequestDate]    Script Date: 2013-10-30 9:49:08 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[EmployeeCalendar_GetOffDate_HolidayDate] 
	@EmpId int,
	@fromDate datetime,
	@toDate datetime
AS
/*
Created: Tom.Vo@2013-10-29
Task: get list days which is Off Day and Holiday for request
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	SELECT WorkDate 
	FROM dbo.EmployeeCalendar WITH(NOLOCK)
	WHERE (WorkDate BETWEEN @fromDate AND @toDate)
		AND EmpID= @EmpId 
		AND (
			(IsHoliday = 1 OR IsOffDay = 1) 
			--AND ShiftId IS NOT NULL
			)
		
END

