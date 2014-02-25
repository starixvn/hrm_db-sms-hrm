USE HRM_SMS
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[WorkingTimeRequest_GetLeaveBalanceEffectedDay]  
	@EffectedDay DATETIME,
	@EmpID INT
 
as
/*
Created: Tom.Vo@2013-11-05
Task: Get  Avaible Balance Leave  
DB: HRM_SMS
Original: 

Revisions:
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON

	DECLARE  @LeaveBalanceDay numeric(18,2),@CreditDays numeric(18,2),@DeductDays numeric(18,2)
	
	SELECT @CreditDays = SUM(ISNULL(CreditDays,0)),
			@DeductDays = SUM(ISNULL(DeductDays,0)) 
	From dbo.LeaveTrans WITH(NOLOCK) Where EmpID= @EmpID AND FromDate <= @EffectedDay AND YEAR(FromDate) = YEAR(@EffectedDay) AND ISNULL(Deleted,0)<>1

	--SELECT @DeductDays = SUM(ISNULL(DeductDays,0)) 
	--From dbo.LeaveTrans WITH(NOLOCK) Where EmpID= @EmpID AND FromDate <= @FromDate AND YEAR(FromDate) = YEAR(@FromDate) 
	
	SELECT @LeaveBalanceDay=@CreditDays-@DeductDays

	SELECT ISNULL(@LeaveBalanceDay,0)
END

