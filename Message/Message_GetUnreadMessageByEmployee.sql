USE [HRM_SMS]
GO
/****** Object:  StoredProcedure [dbo].[Message_GetById]    Script Date: 7/29/2014 9:07:50 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Message_GetUnreadMessageByEmployee] 
	@EmployeeId INT
AS
/*
Created: 20140729@Quinn.Vo
Task: Get unread message by employee.
DB: NexEPA
Original: 

Revisions:  
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT ms.MessageId,
		ms.[Subject],
		ms.[Contents],
		ms.[Category],
		ms.[FromDate],
		ms.[ToDate],
		ISNULL(mse.IsRead, 0) AS IsRead
	FROM dbo.[Message] AS ms WITH (NOLOCK)
	INNER JOIN dbo.MessageGroup AS mg WITH (NOLOCK) ON ms.MessageId = mg.MessageId
	INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON mg.GroupId = e.GroupId
	LEFT JOIN dbo.MessageEmployee AS mse WITH (NOLOCK) ON e.EmpId = mse.EmployeeId AND ms.MessageId = mse.MessageId
	WHERE e.EmpId = @EmployeeId 
		AND mse.EmployeeId IS NULL
	UNION
	SELECT m.MessageId,
		m.[Subject],
		m.[Contents],
		m.[Category],
		m.[FromDate],
		m.[ToDate],
		ISNULL(me.IsRead, 0) AS IsRead
	FROM dbo.[Message] AS m WITH (NOLOCK)
	INNER JOIN dbo.MessageEmployee AS me WITH (NOLOCK) ON m.MessageId = me.MessageId
	WHERE me.EmployeeId = @EmployeeId 
		AND me.IsDisabled = 0
		AND me.IsRead = 0
END
