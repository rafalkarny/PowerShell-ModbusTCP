
# Podstawy
# Modbus ADU Application Data Unit (TCP payload)
# Identyfikator transakcji [2 bajty] |
# Identyfikator Protokołu [2 bajty] (dla Modbus TCP to =0 0x00)|
# Ilość następnych bajtów [2 bajty]  |
# Identyfikator urządzenia slave [1 bajty] (Przydatne jeżeli mamy konwerter Modbus RTU na TCP i więcej urządzeń na magistrali )
# Modbus PDU-Protocol Data Unit 
# Kod funkcji [1 bajty] (01-Read Coils,04-Read Inp.Reg. 03-Read Holding Reg. etc.)
# Początkowy adres [2 bajty]
# Ilość odpytywanych rejestrów [2 bajty]

function Modbus-Read-Coils
{
     #Parametry/Argumenty polecenia:
     Param ([String] $address, [int] $port,[string] $registers, [int] $slaveId) #IP urządzenia, Port, Zakres rejestrów | np: Modbus-Read-Coils 192.168.1.2 502 0-99 2
  
    #Sprawdzanie poprawności podanych argumentów:
    
    # Dla zakresu rejestrów
    [int16]$startRegAddr=0
    [int16]$endRegAddr=1
    [int16]$offset=1

     $RegistersAddrStr=$registers -split '-'
        if($RegistersAddrStr[0] -ge $RegistersAddrStr[1])
        {
            Write-Output "Podano niepoprawny zakres rejestrów, poprawny ciąg: 0-10 "
            return 0
        }
        else
        {
            $startRegAddr=$RegistersAddrStr[0] -as [int16]
            $endRegAddr=$RegistersAddrStr[1] -as [int16]
            $offset=$endRegAddr-$startRegAddr
            #Write-Output $startRegAddr "|" $endRegAddr "|" $offset
            
            #Sprawdzenie czy podana ilość jest wspierana przez Modbusa:
            if($startRegAddr -le 1 -and $endRegAddr -ge 2000)
            {
                Write-Output "Niedozwolony zakres rejestrów"
                return 0
            }
        
        }

   
    # Deklaracja i inicjalizacja pól dla zapytania
    
    # 1.Losowy numer transakcji 
    $random=Get-Random -Maximum 65534   #Można zmniejszyć tą wartość np do 254 w razie problemów
    $TransID=[System.BitConverter]::GetBytes($random)
    #Write-Output "Numer transakcji:" $random "-" $TransID

    
    # 2.Identyfikator protokołu 
    [byte[]]$ProtID=(0x00,0x00)
    #Write-Output "Identyfikator Protokołu:" $ProtID

    # 3.Długość
    [byte[]]$Lenght=(0x06,0x00) #W przypadku zapytania wiemy jaka będzie długość następnych bajtów zapytania ==6 bajtów => 0x06
    #Write-Output "Długość pola danych PDU:" $Lenght

    # 4.Identyfikator urządzenia slave -wykorzystanie jeżeli mamy konwerter z RTU na TCP i więcej urządzeń na magistrali
    #jeżeli nie podano argumentu funcji to wartość =1
    [byte[]]$SlaveID=(0x01,0x00) 
    if($slaveId -gt 1 )
    {
        $SlaveID=[System.BitConverter]::GetBytes([convert]::ToInt16($slaveId))
    }
    #Write-Output "Id urządzeia slave:" $SlaveID

    # 5.Kod funkcji
    [byte] $FunctionCode=(0x01)
    #Write-Output "Kod funkcji Modbus:" $FunctionCode


    # 6.Początkowy adres rejestru
    [byte[]]$StartAddr=[System.BitConverter]::GetBytes([convert]::ToInt16($startRegAddr))
    #Write-Output "Początkowy adres rejestru: " $StartAddr

    # 7.Ilość odpytywanych rejestrów
    [byte[]]$NumberOfRegisters=[System.BitConverter]::GetBytes([convert]::ToInt16($offset))
    #Write-Output "Ilość odpytywanych rejestrów: " $NumberOfRegisters

    #Złożenie w całość

    [byte[]]$ModbusReqPDU=($TransID[1],$TransID[0],$ProtID[1],$ProtID[0],$Lenght[1],$Lenght[0],$SlaveID[0],$FunctionCode,$StartAddr[1],$StartAddr[0],$NumberOfRegisters[1],$NumberOfRegisters[0])

    #Write-Output "Długość zapytania:" 
    #Write-Output $ModbusReqPDU.Length

    #Write-Output "Treść zapytania:"
    #Write-Output $ModbusReqPDU 
    
    try{
        #Utorzenie socket'u TCP i strumienia w pipe
        $tcpConnection = New-Object System.Net.Sockets.TcpClient($address, $port)
        $tcpStream = $tcpConnection.GetStream()
    }
    catch
    {
        Write-Output "Problem z połączeniem do urządzenia."
        Write-Output "Jeżeli urządzenie jest w innej podsieci to upewnij się że:
                        1. Urządzenie docelowe jest podłączone do sieci.
                        2. Port docelowy jest właściwy.
                        3. Jest przepuszczenie na firewall, trasa do urządzenia i portu z którym próbujesz się komunikować:
                        Możesz wykonać polecenie:
                        Test-NetConnection [adres urządzenia] -Port [port docelowy]
                        Dla podanego ciągu wejsiowego będzie to:
                        Test-NetConnection $address -Port $port"
        return 0                
    }

   
    #Deklaracja zmiennej dla buforu wejsciowego
    [byte[]] $buffer = @(0) * 30

    while(1)
    {
        #Wysłanie zapytania
        $tcpStream.Write($ModbusReqPDU,0,$ModbusReqPDU.length)
        #Wyczyszczenie Pipe'a
        $tcpStream.Flush()
        #Sprawdzenie rozmiaru zwracanego PDU
        $size = $tcpStream.Read($buffer,0,$buffer.length)

        #Deklaracja i inicjalizacja zmiennej dla zwracanej odpowiedzi
        $result = @(0) * $size

        [array]::copy($buffer,$result,$size)
        
        #Opóźnienie zapytań
        Start-Sleep -Seconds 1

        #Wyświetlenie odpowiedzi:

        Write-Output "__________________________________________________"

        # 1.Poprzez funckję niżej
        PrintCoils $startRegAddr $endRegAddr $result

        # 2. Surowa odpowiedź do diagnostyki:
        #Write-Output ([String]::Join(',', $result))
    }
    
    $tcpConnection.Close()

    return $result
   
}

#Odpowiedź
# Modbus ADU Application Data Unit (TCP payload)
# Identyfikator transakcji [2 bajty] |
# Identyfikator Protokołu [2 bajty] (dla Modbus TCP to =0 0x00)|
# Ilość następnych bajtów [2 bajty]  |
# Identyfikator urządzenia slave [1 bajty] (Przydatne jeżeli mamy konwerter Modbus RTU na TCP i więcej urządzeń na magistrali )
# Modbus PDU-Protocol Data Unit 
# Kod funkcji [1 bajty] (01-Read Coils,04-Read Inp.Reg. 03-Read Holding Reg. etc.)
# Ilość bajtów zwracanych danych [2 bajty]
# Dane [ilość zależna od zapytania] Dane zwracane są po 8 stanów od największego do najmniejszego indeksu (Big Endian)
function PrintCoils($requestedStartAddress,$requestedEndAddress,[array]$response)
{
    
    $dataLen=($response.Length-9)
    
    if($dataLen -gt 0)
    {
        [byte[]]$values=@(0) * ($response.Length-9)
        [string[]]$binaryValues=@(0) * ($response.Length-9)

        # "ograniczenie tablicy tak żeby zawierała same dane"
        [array]::Copy($response,9,$values,0,$dataLen)
        
        #konwersja danych na format binarny
        $counter=0
        foreach($byte in $values)
        {
             $binaryValues[$counter]=( [System.Convert]::ToString($byte,2).PadLeft(8,'0'))
             $counter++
        }

        #wyświetlanie:
        $regAddr=$requestedStartAddress
        foreach($register in $binaryValues)
        {
            #konwersja typu string na tablicę znaków dla łatwiejszej iteracji
            [char[]]$charArray=$register -as [char[]]
            #zamiana ostatniego znaku(cewki) z pierwszą w tablicy ponieważ wartości zwracane są po 8 od największego do najmniejszego
            [array]::Reverse($charArray)

            foreach($coilValue in $charArray)
            {
                Write-Output  "$regAddr : $coilValue"
                $regAddr++
                if($regAddr -ge $requestedEndAddress)
                {
                    break
                }
            }
        }

    }
    else 
    {
        Write-Output "Nie zwrócono danych"    
    }
    
}
