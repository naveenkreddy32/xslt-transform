<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

    <xsl:output method="xml" indent="yes" encoding="UTF-8" />

    <xsl:variable name="routeDoc" select="/" />
    <xsl:param name="confirmDocIp" />
	<xsl:variable name="confirmDoc" select="parse-xml($confirmDocIp)" />
	
	<xsl:template match="/parameter">
		<param><xsl:value-of select="$confirmDocIp"/></param> 
    </xsl:template>
        
    <xsl:template match="/routeResponse">
        <xsl:for-each select="$confirmDoc//order">
            <xsl:variable name="orderNum" select="orderNumber" />
            <xsl:if test="not($routeDoc//order[orderNumber = $orderNum])">
                <xsl:message terminate="yes">ERROR: Unwanted Order '<xsl:value-of select="$orderNum" />
                    '</xsl:message>
            </xsl:if>
        </xsl:for-each>

        <stopConfirmRequest>
            <stops>
                <xsl:apply-templates select="stops/stop" />
            </stops>
        </stopConfirmRequest>
    </xsl:template>

    <xsl:template match="stop">
        <stop>
            <orders>
                <xsl:for-each select="orders/order">
                    <xsl:variable name="routeOrder" select="." />
                    <xsl:variable name="currentNum" select="orderNumber" />
                    <xsl:variable name="matchOrder"
                        select="$confirmDoc//order[orderNumber = $currentNum]" />

                    <xsl:if test="not($matchOrder)">
                        <xsl:message terminate="yes">ERROR: Missing Order '<xsl:value-of
                                select="$currentNum" />'</xsl:message>
                    </xsl:if>

                    <order>
                        <orderNumber>
                            <xsl:value-of select="$matchOrder/orderNumber" />
                        </orderNumber>
                        <jobType>
                            <xsl:value-of select="$matchOrder/jobType" />
                        </jobType>
                        <orderLines>
                            <xsl:for-each select="$routeOrder/orderLines/orderLine">
                                <xsl:variable name="lID" select="orderLineID" />
                                <xsl:variable name="mLine"
                                    select="$matchOrder/orderLines/orderLine[orderLineID = $lID]" />

                                <xsl:if test="not($mLine)">
                                    <xsl:message terminate="yes">ERROR: Missing Line '<xsl:value-of
                                            select="$lID" />' for order '<xsl:value-of
                                            select="$currentNum" />'</xsl:message>
                                </xsl:if>
                                <xsl:copy-of select="$mLine" />
                            </xsl:for-each>

                            <xsl:for-each select="$matchOrder/orderLines/orderLine">
                                <xsl:variable name="cLineID" select="orderLineID" />
                                <xsl:if
                                    test="not($routeOrder/orderLines/orderLine[orderLineID = $cLineID])">
                                    <xsl:message terminate="yes">ERROR: Unwanted Line '<xsl:value-of
                                            select="$cLineID" />' for order '<xsl:value-of
                                            select="$currentNum" />'</xsl:message>
                                </xsl:if>
                            </xsl:for-each>
                        </orderLines>
                    </order>
                </xsl:for-each>
            </orders>
        </stop>
    </xsl:template>
</xsl:stylesheet>