﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.IO;

namespace netdriver
{
    class SetUp
    {

        public static void IniFile(String filename)
        {
            String[] datalist = { "10,10,'Vicky',10", "11,11,'刘家',11" };
            //create file
            String curpath = Environment.CurrentDirectory;
            String path = curpath + "\\" + filename;
            //File loadfile = new File(path);
            if (File.Exists(path))
            {
                File.Delete(path);
            }
            try
            {
                var fileHanlder = File.Create(path);
                fileHanlder.Close();//释放文件句柄
            }
            catch (Exception fe)
            {
                Console.WriteLine(fe.ToString());
                Console.WriteLine("Create：" + path + "failed！");
                return;
            }

            //write data to file
            StreamWriter sw = null;
            try
            {
                sw = new StreamWriter(path);
            }
            catch (Exception fe)
            {
                Console.WriteLine(fe.ToString());
                return;
            }
            for (int i = 0; i < datalist.Length; i++)
            {
                try
                {
                    sw.WriteLine(datalist[i]);
                }
                catch (IOException e)
                {
                    Console.WriteLine(e.ToString());
                    Console.WriteLine("Write into：" + datalist[i] + "failed！");
                }
            }
            try
            {
                sw.Close();
            }
            catch (Exception fe)
            {
                Console.WriteLine(fe.ToString());
            }
        }
    }
}