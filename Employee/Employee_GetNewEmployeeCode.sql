 
/****** Object:  StoredProcedure [dbo].[Employee_GetEmployeeByCode]    Script Date: 2013-10-29 4:19:18 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Employee_GetNewEmployeeCode]
AS
/*
Created: Tom.Vo@2013-10-21
Task: get employee by code
DB: NexHR
Original: 

Revisions:    
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @Code VARCHAR(10)

	SELECT @Code = MAX(CASE WHEN ISNUMERIC(Right(Code,4))=1 THEN Right(Code,4) ELSE -1 END +1) FROM dbo.Employee WITH(NOLOCK)

	IF @Code IS NOT NULL
		SELECT REPLICATE ( '0' ,4-LEN(@Code))+ @Code AS Code
	ELSE
		SELECT '0001' Code
END
 