USE HRM_SMS
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER FUNCTION [dbo].FNC_GetNewEmpCode()
	returns  NVARCHAR(100)
AS
/*
Created: Tom.Vo@2013-11-05
Task: Get New EmpCode  
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
	
*/ 
BEGIN
	DECLARE  @Code NVARCHAR(100)

	SELECT @Code=Max(Code)  
		FROM [dbo].Employee ee WITH (NOLOCK)  where isnumeric(Code )=1
 
	DECLARE @Num INT
	 --Ref-000001
	 IF ISNULL(@Code,'')=''
		SET @Code='00001'
	ELSE 
		BEGIN
			SET @Num = CONVERT(INT,@Code)+1
			SET @Code=REPLICATE('0', 5-LEN(@Num))+ CONVERT(NVARCHAR(100),@Num)
		END

	RETURN @Code
END