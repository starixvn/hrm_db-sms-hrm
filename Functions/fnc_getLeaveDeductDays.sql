USE [HRM_SMS]
GO
/****** Object:  UserDefinedFunction [dbo].[fnc_LeaveHalfDayID]    Script Date: 2013-12-25 5:28:16 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER function [dbo].[fnc_getLeaveDeductDays]  (@Year INT,@EmpID INT)
returns numeric(18,2)
as

BEGIN

	DECLARE  @LeaveBalanceDay numeric(18,2)
	
	SELECT @LeaveBalanceDay =  SUM(ISNULL(DeductDays,0)) 
	From dbo.LeaveTrans WITH(NOLOCK) 
	Where EmpID= @EmpID 
		AND YEAR(FromDate) = @Year
		AND RequestId IS NOT NULL
		AND ISNULL(Deleted,0)<>1

	RETURN ISNULL(@LeaveBalanceDay,0)
END



