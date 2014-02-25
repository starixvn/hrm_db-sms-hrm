USE [HRM_SMS]
GO
/****** Object:  UserDefinedFunction [dbo].[fnc_LeaveHalfDayID]    Script Date: 2013-12-25 5:28:16 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER function [dbo].[fnc_getLeaveBalanceEffectedDay]  (@FromDate DATETIME,@EmpID INT)
returns numeric(18,2)
as

BEGIN

	DECLARE  @LeaveBalanceDay numeric(18,2),@CreditDays numeric(18,2),@DeductDays numeric(18,2)
	
	SELECT @CreditDays = SUM(ISNULL(CreditDays,0)),
			@DeductDays = SUM(ISNULL(DeductDays,0)) 
	From dbo.LeaveTrans WITH(NOLOCK) Where EmpID= @EmpID AND FromDate <= @FromDate AND YEAR(FromDate) = YEAR(@FromDate) AND ISNULL(Deleted,0)<>1

	--SELECT @DeductDays = SUM(ISNULL(DeductDays,0)) 
	--From dbo.LeaveTrans WITH(NOLOCK) Where EmpID= @EmpID AND FromDate <= @FromDate AND YEAR(FromDate) = YEAR(@FromDate) 
	
	SELECT @LeaveBalanceDay=@CreditDays-@DeductDays

	RETURN ISNULL(@LeaveBalanceDay,0)
END



