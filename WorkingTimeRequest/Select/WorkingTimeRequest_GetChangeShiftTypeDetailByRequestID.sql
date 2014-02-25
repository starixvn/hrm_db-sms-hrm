USE HRM_SMS
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[WorkingTimeRequest_GetChangeShiftTypeDetailByRequestID] 
	@RequestID bigint
AS
/*
Created: Tom.Vo@2013-11-05
Task:Get Request ChangeShiftType Detail By RequestID
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	
	SELECT 
		rd.OnDate,
		s1.ShiftID as FromShiftID, 
		s1.Code as FromShift,
		s2.ShiftID as ToShiftID, 
		s2.Code as ToShift,
		rd.Remark
	FROM  dbo.ChangeShiftRequestDetail rd WITH (NOLOCK) 
		LEFT JOIN dbo.Shift s1 WITH (NOLOCK) ON s1.ShiftID= rd.FromShift
		LEFT JOIN dbo.Shift s2 WITH (NOLOCK) ON s2.ShiftID= rd.ToShift
	WHERE rd.RequestID = @RequestID
	ORDER BY rd.OnDate 
END
