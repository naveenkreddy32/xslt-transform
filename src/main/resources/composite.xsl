<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="xml" indent="yes" />

  <!-- Main template that accepts the composite payload -->
  <xsl:template match="/">
    <!-- Store the two input documents as variables -->
    <xsl:variable name="routeResp" select="root/routeResp/*" />
    <xsl:variable name="stopConfirmReq" select="root/stopConfirmReq/*" />

    <!-- Validate and transform -->
    <xsl:choose>
      <xsl:when test="not($routeResp) or not($stopConfirmReq)">
        <error>
          <message>Missing input: Both routeResp and stopConfirmReq are required</message>
        </error>
      </xsl:when>
      <xsl:otherwise>
        <!-- Perform validation and transformation -->
        <xsl:apply-templates select="$stopConfirmReq" mode="validate-and-transform">
          <xsl:with-param name="routeResp" select="$routeResp" />
        </xsl:apply-templates>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Main transformation template -->
  <xsl:template match="StandardWincantonTMSStopConfirmationRequest" mode="validate-and-transform">
    <xsl:param name="routeResp" />

    <!-- Get the stop number from confirmation -->
    <xsl:variable name="stopNumber" select="stop/stopNumber" />

    <!-- Get corresponding stop from route response -->
    <xsl:variable name="routeStop" select="$routeResp/Route/Stops/Stop[StopNumber = $stopNumber]" />

    <!-- Validate stop exists in route -->
    <xsl:choose>
      <xsl:when test="not($routeStop)">
        <error>
          <message>Stop <xsl:value-of select="$stopNumber" /> not found in route response</message>
        </error>
      </xsl:when>
      <xsl:otherwise>
        <!-- Validate and build output -->
        <xsl:variable name="validationResult">
          <xsl:call-template name="validate-orders">
            <xsl:with-param name="confirmOrders" select="stop/orders/order" />
            <xsl:with-param name="routeOrders" select="$routeStop/Orders/Order" />
          </xsl:call-template>
        </xsl:variable>

        <xsl:choose>
          <xsl:when test="$validationResult/error">
            <xsl:copy-of select="$validationResult" />
          </xsl:when>
          <xsl:otherwise>
            <!-- Build validated output maintaining route order -->
            <StandardWincantonTMSStopConfirmationRequest>
              <routeNumber>
                <xsl:value-of select="routeNumber" />
              </routeNumber>
              <routeDate>
                <xsl:value-of select="routeDate" />
              </routeDate>
              <stop>
                <stopNumber>
                  <xsl:value-of select="$stopNumber" />
                </stopNumber>
                <status>
                  <xsl:value-of select="stop/status" />
                </status>
                <arriveTime>
                  <xsl:value-of select="stop/arriveTime" />
                </arriveTime>
                <completionTime>
                  <xsl:value-of select="stop/completionTime" />
                </completionTime>
                <orders>
                  <!-- Iterate orders in route response order -->
                  <xsl:for-each select="$routeStop/Orders/Order">
                    <xsl:variable name="routeOrderNum" select="OrderNumber" />
                    <xsl:variable name="confirmOrder" select="../../stop/orders/order[orderNumber = $routeOrderNum]" />

                    <order>
                      <orderNumber>
                        <xsl:value-of select="$routeOrderNum" />
                      </orderNumber>
                      <jobType>
                        <xsl:value-of select="$confirmOrder/jobType" />
                      </jobType>
                      <status>
                        <xsl:value-of select="$confirmOrder/status" />
                      </status>
                      <orderLines>
                        <!-- Iterate order lines in route response order -->
                        <xsl:for-each select="OrderLines/OrderLine">
                          <xsl:variable name="routeLineId" select="OrderLineID" />
                          <xsl:variable name="confirmLine" 
                            select="$confirmOrder/orderLines/orderLine[orderLineID = $routeLineId]" />

                          <orderLine>
                            <orderLineID>
                              <xsl:value-of select="$routeLineId" />
                            </orderLineID>
                            <quantity>
                              <xsl:value-of select="$confirmLine/quantity" />
                            </quantity>
                          </orderLine>
                        </xsl:for-each>
                      </orderLines>
                    </order>
                  </xsl:for-each>
                </orders>
              </stop>
            </StandardWincantonTMSStopConfirmationRequest>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Validation template for orders -->
  <xsl:template name="validate-orders">
    <xsl:param name="confirmOrders" />
    <xsl:param name="routeOrders" />

    <!-- Check for missing orders in confirmation -->
    <xsl:for-each select="$routeOrders">
      <xsl:variable name="routeOrderNum" select="OrderNumber" />
      <xsl:if test="not($confirmOrders[orderNumber = $routeOrderNum])">
        <error>
          <message>Order <xsl:value-of select="$routeOrderNum" /> missing in stop confirmation</message>
        </error>
      </xsl:if>
    </xsl:for-each>

    <!-- Check for additional orders in confirmation -->
    <xsl:for-each select="$confirmOrders">
      <xsl:variable name="confirmOrderNum" select="orderNumber" />
      <xsl:if test="not($routeOrders[OrderNumber = $confirmOrderNum])">
        <error>
          <message>Order <xsl:value-of select="$confirmOrderNum" /> in confirmation but not in route</message>
        </error>
      </xsl:if>
    </xsl:for-each>

    <!-- Validate each order's job type and order lines -->
    <xsl:for-each select="$routeOrders">
      <xsl:variable name="routeOrderNum" select="OrderNumber" />
      <xsl:variable name="routeJobType" select="JobType" />
      <xsl:variable name="confirmOrder" select="$confirmOrders[orderNumber = $routeOrderNum]" />

      <!-- Check job type matches -->
      <xsl:if test="$confirmOrder/jobType != $routeJobType">
        <error>
          <message>Order <xsl:value-of select="$routeOrderNum" />: jobType mismatch. Expected '<xsl:value-of select="$routeJobType" />', got '<xsl:value-of select="$confirmOrder/jobType" />'</message>
        </error>
      </xsl:if>

      <!-- Check for missing order lines in confirmation -->
      <xsl:for-each select="OrderLines/OrderLine">
        <xsl:variable name="routeLineId" select="OrderLineID" />
        <xsl:if test="not($confirmOrder/orderLines/orderLine[orderLineID = $routeLineId])">
          <error>
            <message>Order <xsl:value-of select="$routeOrderNum" />: OrderLine <xsl:value-of select="$routeLineId" /> missing in confirmation</message>
          </error>
        </xsl:if>
      </xsl:for-each>

      <!-- Check for additional order lines in confirmation -->
      <xsl:for-each select="$confirmOrder/orderLines/orderLine">
        <xsl:variable name="confirmLineId" select="orderLineID" />
        <xsl:variable name="routeOrder" select="$routeOrders[OrderNumber = $confirmOrder/orderNumber]" />
        <xsl:if test="not($routeOrder/OrderLines/OrderLine[OrderLineID = $confirmLineId])">
          <error>
            <message>Order <xsl:value-of select="$routeOrderNum" />: OrderLine <xsl:value-of select="$confirmLineId" /> in confirmation but not in route</message>
          </error>
        </xsl:if>
      </xsl:for-each>
    </xsl:for-each>
  </xsl:template>

</xsl:stylesheet>
